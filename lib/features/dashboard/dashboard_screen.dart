import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/app_providers.dart';
import '../../widgets/member_avatar.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final activeFront = ref.watch(activeFrontProvider);
    final members = ref.watch(membersProvider);
    final switches = ref.watch(switchProvider);

    final fronter = activeFront != null
        ? ref.read(membersProvider.notifier).byId(activeFront.memberId)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(config.systemName ?? 'PluralLog System Template'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Front',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (fronter != null) ...[
                    Row(
                      children: [
                        MemberAvatar(member: fronter, size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fronter.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge),
                              if (fronter.pronouns != null)
                                Text(fronter.pronouns!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                              Text(
                                'Since ${DateFormat.jm().format(activeFront!.startTime)}',
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (activeFront!.cofronterIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Co-fronting: ${activeFront.cofronterIds.map((id) {
                          final m = ref
                              .read(membersProvider.notifier)
                              .byId(id);
                          return m?.name ?? id;
                        }).join(', ')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      /* As a note, this style of displaying fronts/cofronts is what causes 
                      our UI overflow bug in the actual PluralLog app. We'll likely just wrap it in
                      a scrollbar, */
                    ],
                  ] else
                    const Text('No one is currently fronting.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('System Overview',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text('${members.length} members registered'),
                  Text('${switches.length} switch events recorded'),
                  if (config.federationEnabled)
                    Text(
                        'Federation: connected to ${config.federationServerUrl ?? "unknown"}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
