import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/member.dart';
import '../../core/providers/app_providers.dart';
import '../../widgets/member_avatar.dart';

const _uuid = Uuid();

const _palette = [
  Color(0xFFE57373), Color(0xFF81C784), Color(0xFF64B5F6),
  Color(0xFFFFD54F), Color(0xFFBA68C8), Color(0xFF4DB6AC),
  Color(0xFFFF8A65), Color(0xFFA1887F), Color(0xFF90A4AE),
  Color(0xFFF06292),
]; // Not an arbitrary hex code, but an extendable set? This can be popped out easily. We started dev prior to doing that in PluralLog. 

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider);
    final topLevel = members.where((m) => m.parentMemberId == null).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMemberDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: members.isEmpty
          ? const Center(child: Text('No members yet. Tap + to add one.'))
          : ListView.builder(
              itemCount: topLevel.length,
              itemBuilder: (context, i) {
                final member = topLevel[i];
                final children = members
                    .where((m) => m.parentMemberId == member.id)
                    .toList();
                return Column(
                  children: [
                    _memberTile(context, ref, member),
                    ...children.map((c) => Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: _memberTile(context, ref, c),
                        )),
                  ],
                );
              },
            ),
    );
  }

  Widget _memberTile(BuildContext context, WidgetRef ref, Member member) {
    return ListTile(
      leading: MemberAvatar(member: member),
      title: Text(member.name),
      subtitle: Text([
        if (member.pronouns != null) member.pronouns!,
        if (member.role != null) member.role!,
      ].join(' - ')),
      trailing: PopupMenuButton(
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
        onSelected: (value) {
          if (value == 'edit') {
            _showMemberDialog(context, ref, existing: member);
          } else if (value == 'delete') {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Member'),
                content: Text(
                    'Remove ${member.name} and all associated data?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      ref.read(membersProvider.notifier).remove(member.id);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  void _showMemberDialog(BuildContext context, WidgetRef ref,
      {Member? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final pronounsCtrl =
        TextEditingController(text: existing?.pronouns ?? '');
    final roleCtrl = TextEditingController(text: existing?.role ?? '');
    final descCtrl =
        TextEditingController(text: existing?.description ?? '');
    Color selectedColor = existing?.color ?? _palette[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing != null ? 'Edit Member' : 'Add Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Name')),
                TextField(
                    controller: pronounsCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Pronouns')),
                TextField(
                    controller: roleCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Role')),
                TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Description'),
                    maxLines: 2),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: _palette
                      .map((c) => GestureDetector(
                            onTap: () => setState(() => selectedColor = c),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: c,
                              child: selectedColor == c
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : null,
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final member = (existing ??
                        Member(
                          id: _uuid.v4(),
                          name: '',
                          color: selectedColor,
                        ))
                    .copyWith(
                  name: nameCtrl.text.trim(),
                  pronouns: pronounsCtrl.text.trim().isNotEmpty
                      ? pronounsCtrl.text.trim()
                      : null,
                  role: roleCtrl.text.trim().isNotEmpty
                      ? roleCtrl.text.trim()
                      : null,
                  description: descCtrl.text.trim().isNotEmpty
                      ? descCtrl.text.trim()
                      : null,
                  color: selectedColor,
                );
                if (existing != null) {
                  ref.read(membersProvider.notifier).update(member);
                } else {
                  ref.read(membersProvider.notifier).add(member);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
