import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/poll.dart';
import '../../core/providers/app_providers.dart';

const _uuid = Uuid();

class PollsScreen extends ConsumerWidget {
  const PollsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final polls = ref.watch(pollsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Polls')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: polls.isEmpty
          ? const Center(child: Text('No polls yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: polls.length,
              itemBuilder: (context, i) {
                final poll = polls[i];
                final tallies = poll.tallies;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(poll.question,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall),
                            ),
                            if (poll.closed)
                              const Chip(label: Text('Closed')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(poll.options.length, (oi) {
                          final count = tallies[oi] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('${poll.options[oi]}: $count vote(s)'),
                          );
                        }),
                        Text('Total: ${poll.totalVotes} vote(s)',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final questionCtrl = TextEditingController();
    final optionCtrls = [TextEditingController(), TextEditingController()];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Poll'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: questionCtrl,
                  decoration: const InputDecoration(labelText: 'Question')),
              ...List.generate(
                optionCtrls.length,
                (i) => TextField(
                    controller: optionCtrls[i],
                    decoration:
                        InputDecoration(labelText: 'Option ${i + 1}')),
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
              final q = questionCtrl.text.trim();
              final opts = optionCtrls
                  .map((c) => c.text.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              if (q.isEmpty || opts.length < 2) return;
              ref.read(pollsProvider.notifier).add(Poll(
                    id: _uuid.v4(),
                    question: q,
                    options: opts,
                    createdAt: DateTime.now(),
                  ));
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
