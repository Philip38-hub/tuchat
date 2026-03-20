import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuchat/models/chat.dart';
import 'package:tuchat/models/message.dart';
import 'package:tuchat/models/user.dart';
import 'package:tuchat/providers/chat_session_provider.dart';
import 'package:tuchat/services/chat_service.dart';
import 'package:tuchat/utils/profile_image.dart';
import 'package:video_player/video_player.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.currentUser,
    required this.otherUser,
    required this.chat,
  });

  final AppUser currentUser;
  final AppUser otherUser;
  final Chat chat;

  @override
  Widget build(BuildContext context) {
    final chatService = context.read<ChatService>();

    return ChangeNotifierProvider(
      create: (_) => ChatSessionProvider(
        chatService: chatService,
        chat: chat,
        currentUserId: currentUser.uid,
        otherUserId: otherUser.uid,
      ),
      child: _ChatScreenView(
        currentUser: currentUser,
        otherUser: otherUser,
        chat: chat,
      ),
    );
  }
}

class _ChatScreenView extends StatefulWidget {
  const _ChatScreenView({
    required this.currentUser,
    required this.otherUser,
    required this.chat,
  });

  final AppUser currentUser;
  final AppUser otherUser;
  final Chat chat;

  @override
  State<_ChatScreenView> createState() => _ChatScreenViewState();
}

class _ChatScreenViewState extends State<_ChatScreenView> {
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _editingMessageId;

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitComposer() async {
    final provider = context.read<ChatSessionProvider>();
    final text = _composerController.text;
    if (text.trim().isEmpty) {
      return;
    }

    try {
      if (_editingMessageId != null) {
        await provider.editMessage(
          messageId: _editingMessageId!,
          content: text,
        );
      } else {
        await provider.sendTextMessage(text);
      }

      _composerController.clear();
      setState(() {
        _editingMessageId = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _startEditing(Message message, String displayContent) {
    setState(() {
      _editingMessageId = message.id;
      _composerController.text = displayContent;
      _composerController.selection = TextSelection.fromPosition(
        TextPosition(offset: _composerController.text.length),
      );
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _composerController.clear();
    });
  }

  Future<void> _showMessageActions(Message message, String displayContent) async {
    final provider = context.read<ChatSessionProvider>();

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () {
                  Navigator.of(context).pop();
                  _startEditing(message, displayContent);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete message'),
                onTap: () async {
                  Navigator.of(context).pop();
                  try {
                    await provider.deleteMessage(message.id);
                  } catch (error) {
                    if (!context.mounted) {
                      return;
                    }

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatService = context.read<ChatService>();

    return StreamProvider<Chat?>.value(
      value: chatService.streamChat(widget.chat.id),
      initialData: widget.chat,
      child: Builder(
        builder: (context) {
          final liveChat = context.watch<Chat?>();

          return StreamProvider<List<Message>>.value(
            value: chatService.streamMessages(widget.chat.id),
            initialData: const [],
            child: Consumer<ChatSessionProvider>(
              builder: (context, provider, _) {
                final messages = context.watch<List<Message>>();
                _markReadAfterFrame(messages);
                _scrollAfterFrame(messages);

                return Scaffold(
                  appBar: AppBar(
                    titleSpacing: 0,
                    title: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: buildProfileImageProvider(
                            widget.otherUser.profilePicUrl,
                          ),
                          child: widget.otherUser.profilePicUrl.isEmpty
                              ? Text(widget.otherUser.username.substring(0, 1).toUpperCase())
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(widget.otherUser.username),
                              Text(
                                liveChat?.isUserTyping(widget.otherUser.uid) == true
                                    ? 'Typing...'
                                    : (liveChat?.isSecretChat == true
                                          ? 'Secret chat'
                                          : 'Online in TuChat'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (liveChat?.isSecretChat == true)
                          const Icon(Icons.lock_outline),
                      ],
                    ),
                  ),
                  body: Column(
                    children: [
                      Expanded(
                        child: messages.isEmpty
                            ? const Center(
                                child: Text('No messages yet. Start the conversation.'),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final isMine =
                                      message.senderId == widget.currentUser.uid;

                                  return _MessageBubble(
                                    message: message,
                                    isMine: isMine,
                                    currentUserId: widget.currentUser.uid,
                                    chatService: chatService,
                                    onLongPress: isMine && !message.isDeleted
                                        ? (displayContent) => _showMessageActions(
                                            message,
                                            displayContent,
                                          )
                                        : null,
                                  );
                                },
                              ),
                      ),
                      if (_editingMessageId != null)
                        Material(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: ListTile(
                            title: const Text('Editing message'),
                            subtitle: const Text('Update the text and send to save changes.'),
                            trailing: IconButton(
                              onPressed: _cancelEditing,
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: provider.isBusy
                                    ? null
                                    : () async {
                                        try {
                                          await provider.pickAndSendMedia();
                                        } catch (error) {
                                          if (!context.mounted) {
                                            return;
                                          }

                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(error.toString())),
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.attach_file),
                                tooltip: 'Attach media',
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _composerController,
                                  minLines: 1,
                                  maxLines: 5,
                                  onChanged: provider.onComposerChanged,
                                  decoration: InputDecoration(
                                    hintText: liveChat?.isSecretChat == true
                                        ? 'Send an encrypted message'
                                        : 'Type a message',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: provider.isBusy ? null : _submitComposer,
                                icon: Icon(
                                  _editingMessageId != null ? Icons.check : Icons.send,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _markReadAfterFrame(List<Message> messages) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final hasUnread = messages.any(
        (message) =>
            message.receiverId == widget.currentUser.uid && !message.isRead,
      );
      if (hasUnread) {
        unawaited(context.read<ChatSessionProvider>().markMessagesAsRead());
      }
    });
  }

  void _scrollAfterFrame(List<Message> messages) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || messages.isEmpty) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.currentUserId,
    required this.chatService,
    this.onLongPress,
  });

  final Message message;
  final bool isMine;
  final String currentUserId;
  final ChatService chatService;
  final Future<void> Function(String displayContent)? onLongPress;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Card(
          color: bubbleColor,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            onLongPress: onLongPress == null
                ? null
                : () async {
                    final displayContent = await _displayContent();
                    await onLongPress!(displayContent);
                  },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MessageBody(
                    message: message,
                    currentUserId: currentUserId,
                    chatService: chatService,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (message.isEdited) ...[
                        const SizedBox(width: 6),
                        Text(
                          'edited',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (isMine) ...[
                        const SizedBox(width: 6),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<String> _displayContent() async {
    if (message.isDeleted) {
      return '';
    }

    if (!message.isSecret) {
      return message.content;
    }

    return chatService.decryptMessageForUser(uid: currentUserId, message: message);
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({
    required this.message,
    required this.currentUserId,
    required this.chatService,
  });

  final Message message;
  final String currentUserId;
  final ChatService chatService;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Text(
        'Message deleted',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (message.type == MessageType.image && message.mediaUrl?.isNotEmpty == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: message.mediaUrl!,
          fit: BoxFit.cover,
          placeholder: (context, _) =>
              const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
          errorWidget: (context, _, _) => const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Unable to load image.'),
          ),
        ),
      );
    }

    if (message.type == MessageType.video && message.mediaUrl?.isNotEmpty == true) {
      return _VideoMessagePlayer(url: message.mediaUrl!);
    }

    if (message.isSecret) {
      return FutureBuilder<String>(
        future: chatService.decryptMessageForUser(
          uid: currentUserId,
          message: message,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Text('Decrypting...');
          }

          if (snapshot.hasError) {
            return const Text('Unable to decrypt message on this device.');
          }

          return Text(snapshot.data ?? '');
        },
      );
    }

    return Text(message.content);
  }
}

class _VideoMessagePlayer extends StatefulWidget {
  const _VideoMessagePlayer({required this.url});

  final String url;

  @override
  State<_VideoMessagePlayer> createState() => _VideoMessagePlayerState();
}

class _VideoMessagePlayerState extends State<_VideoMessagePlayer> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: VideoPlayer(controller),
          ),
        ),
        const SizedBox(height: 8),
        IconButton(
          onPressed: () {
            if (controller.value.isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
            setState(() {});
          },
          icon: Icon(
            controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
          ),
        ),
      ],
    );
  }
}
