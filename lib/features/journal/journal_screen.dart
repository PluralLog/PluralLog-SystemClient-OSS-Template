import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/journal_entry.dart';
import '../../core/providers/app_providers.dart';

const _uuid = Uuid();

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(journalProvider);
    final members = ref.watch(membersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: entries.isEmpty
          ? const Center(child: Text('No journal entries yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final entry = entries[i];
                final author =
                    ref.read(membersProvider.notifier).byId(entry.authorId);
                final emotion = Emotion.byName(entry.emotion);
                return Card(
                  child: ListTile(
                    leading: emotion != null
                        ? Text(emotion.label,
                            style: TextStyle(
                                color: Color(emotion.colorValue)))
                        : null,
                    title: Text(entry.text, maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${author?.name ?? "Unknown"} -- '
                      '${DateFormat.yMd().add_jm().format(entry.timestamp)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () =>
                          ref.read(journalProvider.notifier).remove(entry.id),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final textCtrl = TextEditingController();
    final members = ref.read(membersProvider);
    String? selectedAuthor = members.isNotEmpty ? members.first.id : null;
    String? selectedEmotion;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Journal Entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (members.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: selectedAuthor,
                  decoration: const InputDecoration(labelText: 'Author'),
                  items: members
                      .map((m) =>
                          DropdownMenuItem(value: m.id, child: Text(m.name)))
                      .toList(),
                  onChanged: (v) => selectedAuthor = v,
                ),
              DropdownButtonFormField<String>(
                value: selectedEmotion,
                decoration: const InputDecoration(labelText: 'Emotion'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...Emotion.all.map((e) =>
                      DropdownMenuItem(value: e.name, child: Text(e.label))),
                ],
                onChanged: (v) => selectedEmotion = v,
              ),
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(labelText: 'Entry text'),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (textCtrl.text.trim().isEmpty || selectedAuthor == null) return;
              ref.read(journalProvider.notifier).add(JournalEntry(
                    id: _uuid.v4(),
                    authorId: selectedAuthor!,
                    text: textCtrl.text.trim(),
                    emotion: selectedEmotion,
                    timestamp: DateTime.now(),
                  ));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
