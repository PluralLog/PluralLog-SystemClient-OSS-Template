import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/app_providers.dart';
import '../../widgets/member_avatar.dart';

class SwitchingScreen extends ConsumerWidget {
  const SwitchingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider);
    final switches = ref.watch(switchProvider);
    final activeFront = ref.watch(activeFrontProvider);

    final recentSwitches = List.of(switches)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    return Scaffold(
      appBar: AppBar(title: const Text('Switch')),
      body: Column(
        children: [
          if (members.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Switch to:',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: members.map((m) {
                      final isFronting =
                          activeFront?.memberId == m.id;
                      return ActionChip(
                        avatar: MemberAvatar(member: m, size: 24),
                        label: Text(m.name),
                        backgroundColor: isFronting
                            ? m.color.withValues(alpha: .3) 
                            : null,
                        onPressed: isFronting
                            ? null
                            : () => ref
                                .read(switchProvider.notifier)
                                .switchTo(m.id),
                      );
                    }).toList(),
                  ),
                  if (activeFront != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          ref.read(switchProvider.notifier).endCurrent(),
                      child: const Text('End current front'),
                    ),
                  ],
                ],
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Recent Switches',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          Expanded(
            child: recentSwitches.isEmpty
                ? const Center(child: Text('No switches recorded yet.'))
                : ListView.builder(
                    itemCount: recentSwitches.length,
                    itemBuilder: (context, i) {
                      final sw = recentSwitches[i];
                      final member = ref
                          .read(membersProvider.notifier)
                          .byId(sw.memberId);
                      final name = member?.name ?? sw.memberId;
                      final duration = sw.duration;
                      return ListTile(
                        leading: member != null
                            ? MemberAvatar(member: member, size: 32)
                            : const CircleAvatar(
                                child: Icon(Icons.person)),
                        title: Text(name),
                        subtitle: Text(
                          '${DateFormat.yMd().add_jm().format(sw.startTime)}'
                          '${duration != null ? " (${_formatDuration(duration)})" : " (active)"}',
                        ),
                        trailing: sw.isActive
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }
}
