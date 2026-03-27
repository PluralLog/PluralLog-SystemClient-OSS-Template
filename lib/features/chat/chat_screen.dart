import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/chat_message.dart';
import '../../core/providers/app_providers.dart';

const _uuid = Uuid();

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsProvider);
    final selectedId = ref.watch(selectedChannelProvider);
    final selected = selectedId ?? (channels.isNotEmpty ? channels.first.id : null);
    final messages = ref.watch(messagesProvider);
    final channelMessages = selected != null
        ? ref.read(messagesProvider.notifier).forChannel(selected)
        : <ChatMessage>[];
    final members = ref.watch(membersProvider);
    final senderId = ref.watch(chatSenderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Internal Chat'),
        actions: [
          if (channels.isNotEmpty)
            DropdownButton<String>(
              value: selected,
              underline: const SizedBox(),
              items: channels
                  .map((c) =>
                      DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) =>
                  ref.read(selectedChannelProvider.notifier).state = v,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: channelMessages.isEmpty
                ? const Center(child: Text('No messages in this channel.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: channelMessages.length,
                    itemBuilder: (context, i) {
                      final msg = channelMessages[i];
                      final author =
                          ref.read(membersProvider.notifier).byId(msg.authorId);
                      return ListTile(
                        dense: true,
                        title: Text(msg.text),
                        subtitle: Text(
                          '${author?.name ?? msg.authorId} -- '
                          '${DateFormat.jm().format(msg.timestamp)}',
                        ),
                      );
                    },
                  ),
          ),
          if (selected != null)
            _MessageInput(channelId: selected),
        ],
      ),
    );
  }
}

class _MessageInput extends ConsumerStatefulWidget {
  final String channelId;
  const _MessageInput({required this.channelId});

  @override
  ConsumerState<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<_MessageInput> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(membersProvider);
    final senderId = ref.watch(chatSenderProvider);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          if (members.isNotEmpty)
            DropdownButton<String>(
              value: senderId ?? (members.isNotEmpty ? members.first.id : null),
              hint: const Text('Who'),
              underline: const SizedBox(),
              items: members
                  .map((m) =>
                      DropdownMenuItem(value: m.id, child: Text(m.name)))
                  .toList(),
              onChanged: (v) =>
                  ref.read(chatSenderProvider.notifier).state = v,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                hintText: 'Message...',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _send,
          ),
        ],
      ),
    );
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final members = ref.read(membersProvider);
    final senderId =
        ref.read(chatSenderProvider) ?? (members.isNotEmpty ? members.first.id : null);
    if (senderId == null) return;

    ref.read(messagesProvider.notifier).send(ChatMessage(
          id: _uuid.v4(),
          channelId: widget.channelId,
          authorId: senderId,
          text: text,
          timestamp: DateTime.now(),
        ));
    _ctrl.clear();
  }
}
