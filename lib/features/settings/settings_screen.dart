import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../core/providers/app_providers.dart';
import '../../core/database/local_database.dart';
import '../federation/federation_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // System name
          ListTile(
            title: const Text('System Name'),
            subtitle: Text(config.systemName ?? 'Not set'),
            trailing: const Icon(Icons.edit),
            onTap: () => _editSystemName(context, ref, config.systemName),
          ),
          const Divider(),

          // Federation
          ListTile(
            title: const Text('Federation'),
            subtitle: Text(config.federationEnabled
                ? 'Connected to ${config.federationServerUrl}'
                : 'Not connected'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FederationScreen()),
            ),
          ),
          const Divider(),

          // Export
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Export Data'),
            subtitle: const Text('Save all data as a PluralLog JSON file'),
            onTap: () => _exportData(context, ref),
          ),

          // Import
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Import Data'),
            subtitle: const Text('Load from a PluralLog JSON export'),
            onTap: () => _importData(context, ref),
          ),
          const Divider(),

          // Delete all
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title:
                const Text('Delete All Data', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  void _editSystemName(
      BuildContext context, WidgetRef ref, String? current) {
    final ctrl = TextEditingController(text: current ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('System Name'),
        content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final config = ref.read(configProvider);
              ref.read(configProvider.notifier).update(
                  config.copyWith(systemName: ctrl.text.trim()));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }


/*
With the data functions, and this is only relevant if using the PluralLog format/provided DB, it doesn't
matter much what the intermittent data states are like. You could for example encrypt data locally, store
it to an SQLite DB, or store it in the cloud (advertise to users openly). Keep this in mind, don't let
these rinky functions prevent creativity!
*/

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    /* If you want to build this on iOS, you may need to add the NS Photo permission to your 
    plist, and you may need to specify a share oriogin - which is just a rectangular region 
    the share notif/action comes from. We haven't tested this on iOS, but I expect that may be an issue.*/
    try {
      final path = await LocalDatabase.instance.exportToFile();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to $path')),
      );
      await Share.shareXFiles([XFile(path)]);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;
      final content = await File(result.files.single.path!).readAsString();
      final summary = await LocalDatabase.instance.importData(content);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Imported: ${summary.entries.map((e) => "${e.value} ${e.key}").join(", ")}'),
      ));
      // Refresh providers
      ref.invalidate(membersProvider);
      ref.invalidate(switchProvider);
      ref.invalidate(journalProvider);
      ref.invalidate(pollsProvider);
      ref.invalidate(channelsProvider);
      ref.invalidate(messagesProvider);
      ref.invalidate(configProvider);
    } on FormatException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import error: ${e.message}')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data'),
        content: const Text(
            'This will permanently remove all local data. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await LocalDatabase.instance.deleteAllData();
              ref.invalidate(membersProvider);
              ref.invalidate(switchProvider);
              ref.invalidate(journalProvider);
              ref.invalidate(pollsProvider);
              ref.invalidate(channelsProvider);
              ref.invalidate(messagesProvider);
              ref.invalidate(configProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }
}
