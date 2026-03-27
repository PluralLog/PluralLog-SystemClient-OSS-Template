import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/federation/federation.dart';

/*
 Demonstrates the federation connect/disconnect flow and sharing management.

 In a production app you would also wire up auto-sync on app resume,
 background sync, and re-keying after revocation. This screen shows
 the API calls involved.

 Expect more detailed resources on this flow at a later date. 
*/
class FederationScreen extends ConsumerStatefulWidget {
  const FederationScreen({super.key});

  @override
  ConsumerState<FederationScreen> createState() => _FederationScreenState();
}

class _FederationScreenState extends ConsumerState<FederationScreen> {
  final _serverUrlCtrl = TextEditingController();
  final _handleCtrl = TextEditingController();
  FederationClient? _client;
  VolumeManager? _volumeManager;
  List<SharingRelationship> _pendingRequests = [];
  List<SharingRelationship> _activeShares = [];
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _initFromConfig();
  }

  void _initFromConfig() {
    final config = ref.read(configProvider);
    if (config.federationEnabled && config.federationServerUrl != null) {
      _serverUrlCtrl.text = config.federationServerUrl!;
      _handleCtrl.text = config.federationHandle ?? '';
    }
  }

  void _setStatus(String msg) => setState(() => _status = msg);

  Future<void> _connect() async {
    final url = _serverUrlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _busy = true);
    _setStatus('Generating identity...');

    try {
      await FederationCrypto.generateIdentity();

      _client = FederationClient();
      _client!.configure(url);

      _setStatus('Registering with server...');
      final userId = await _client!.register(
          handle: _handleCtrl.text.trim().isNotEmpty
              ? _handleCtrl.text.trim()
              : null);

      _setStatus('Authenticating...');
      await _client!.authenticate();

      // Persist to config
      final config = ref.read(configProvider);
      await ref.read(configProvider.notifier).update(config.copyWith(
            federationEnabled: true,
            federationServerUrl: url,
            federationHandle: _handleCtrl.text.trim(),
            federationUserId: userId,
          ));

      _setStatus('Connected as $userId');
      await _loadSharing();
    } catch (e) {
      _setStatus('Connection failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    if (_client == null || !_client!.isAuthenticated) {
      _setStatus('Not authenticated. Connect first.');
      return;
    }
    setState(() => _busy = true);
    _setStatus('Syncing volumes...');

    try {
      final db = ref.read(databaseProvider);
      _volumeManager ??= VolumeManager(
        db: db,
        client: _client!,
        versions: VolumeVersions(),
      );
      final uploaded = await _volumeManager!.syncAll();
      _setStatus('Synced ${uploaded.length} volumes: ${uploaded.join(", ")}');
    } catch (e) {
      _setStatus('Sync failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _loadSharing() async {
    if (_client == null) return;
    try {
      _pendingRequests = await _client!.getPendingRequests();
      _activeShares = await _client!.getActiveSharings();
      setState(() {});
    } catch (e) {
      _setStatus('Failed to load sharing data: $e');
    }
  }

  Future<void> _acceptRequest(SharingRelationship req) async {
    if (req.friendExchangePublicKey == null) {
      _setStatus('Missing friend exchange key from server.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _client!.acceptSharing(
        requestId: req.id,
        friendExchangePublicKey: req.friendExchangePublicKey!,
        permissions: SharingPermissions(),
      );
      _setStatus('Accepted sharing request.');
      await _loadSharing();
    } catch (e) {
      _setStatus('Accept failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    try {
      if (_client != null && _client!.isAuthenticated) {
        try {
          await _client!.deleteAccount();
        } catch (_) {}
      }
      await FederationCrypto.deleteKeys();
      final config = ref.read(configProvider);
      await ref.read(configProvider.notifier).update(config.copyWith(
            federationEnabled: false,
            clearServerUrl: true,
            clearHandle: true,
            clearUserId: true,
          ));
      _client?.disconnect();
      _client = null;
      _pendingRequests = [];
      _activeShares = [];
      _setStatus('Disconnected.');
    } catch (e) {
      _setStatus('Disconnect error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Federation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection form
          TextField(
            controller: _serverUrlCtrl,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'https://your-relay.example.com',
              /* Strictly speaking, it is not necessary to let a user choose their own 
              arbitrary relay. We suggest it, but you could modify this screen to automatically
              attempt connections when network is available, and just display general state data.*/
            ),
            enabled: !config.federationEnabled,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _handleCtrl,
            decoration: const InputDecoration(
              labelText: 'Display handle (optional)',
            ),
            enabled: !config.federationEnabled,
          ),
          const SizedBox(height: 16),

          if (!config.federationEnabled)
            FilledButton(
              onPressed: _busy ? null : _connect,
              child: const Text('Connect'),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _syncNow,
                    child: const Text('Sync Now'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _disconnect,
                  child: const Text('Disconnect'),
                ),
              ],
            ),
            if (config.federationUserId != null) ...[
              const SizedBox(height: 8),
              Text('User ID: ${config.federationUserId}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],

          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],

          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(_status!, style: Theme.of(context).textTheme.bodySmall),
          ],

          // Pending requests
          if (_pendingRequests.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Pending Requests',
                style: Theme.of(context).textTheme.titleSmall),
            ..._pendingRequests.map((req) => ListTile(
                  title: Text(req.friendHandle ?? req.friendUserId),
                  subtitle: const Text('Wants to connect'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () => _acceptRequest(req),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          await _client?.rejectSharing(req.id);
                          await _loadSharing();
                        },
                      ),
                    ],
                  ),
                )),
          ],

          // Active shares
          if (_activeShares.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Active Shares',
                style: Theme.of(context).textTheme.titleSmall),
            ..._activeShares.map((share) => ListTile(
                  title: Text(share.friendHandle ?? share.friendUserId),
                  subtitle: const Text('Active'),
                  trailing: IconButton(
                    icon: const Icon(Icons.link_off),
                    onPressed: () async {
                      await _client?.revokeSharing(share.id);
                      await FederationCrypto.rekeyVolumeKey();
                      _setStatus(
                          'Revoked. VEK rotated. Re-wrap remaining shares in production.');
                      await _loadSharing();
                    },
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
