import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tuchat/models/chat.dart';
import 'package:tuchat/services/chat_service.dart';

class ChatSessionProvider extends ChangeNotifier {
  ChatSessionProvider({
    required ChatService chatService,
    required Chat chat,
    required String currentUserId,
    required String otherUserId,
  }) : _chatService = chatService,
       _chat = chat,
       _currentUserId = currentUserId,
       _otherUserId = otherUserId;

  final ChatService _chatService;
  final String _currentUserId;
  final String _otherUserId;

  final Chat _chat;
  bool _isBusy = false;
  String? _errorMessage;
  Timer? _typingDebounce;
  bool _disposed = false;
  bool _isTyping = false;

  Chat get chat => _chat;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  Future<void> sendTextMessage(String content) async {
    await _run(() {
      return _chatService.sendTextMessage(
        chat: _chat,
        senderId: _currentUserId,
        receiverId: _otherUserId,
        content: content,
      );
    });
    await setTyping(false);
  }

  Future<void> editMessage({
    required String messageId,
    required String content,
  }) async {
    await _run(() {
      return _chatService.editMessage(
        chat: _chat,
        messageId: messageId,
        editorId: _currentUserId,
        newContent: content,
        receiverId: _otherUserId,
      );
    });
  }

  Future<void> deleteMessage(String messageId) async {
    await _run(() {
      return _chatService.deleteMessage(
        chatId: _chat.id,
        messageId: messageId,
        requesterId: _currentUserId,
      );
    });
  }

  Future<void> markMessagesAsRead() async {
    try {
      await _chatService.markMessagesAsRead(
        chatId: _chat.id,
        viewerId: _currentUserId,
      );
    } catch (error) {
      _errorMessage = error.toString();
      _safeNotify();
    }
  }

  Future<void> pickAndSendMedia() async {
    await _run(() {
      return _chatService.sendMediaMessage(
        chatId: _chat.id,
        senderId: _currentUserId,
        receiverId: _otherUserId,
      );
    });
  }

  void onComposerChanged(String value) {
    final hasText = value.trim().isNotEmpty;
    if (hasText && !_isTyping) {
      unawaited(setTyping(true));
    } else if (!hasText && _isTyping) {
      unawaited(setTyping(false));
    }

    _typingDebounce?.cancel();
    if (hasText) {
      _typingDebounce = Timer(
        const Duration(seconds: 2),
        () => unawaited(setTyping(false)),
      );
    }
  }

  Future<void> setTyping(bool isTyping) async {
    if (_isTyping == isTyping) {
      return;
    }

    _isTyping = isTyping;
    try {
      await _chatService.updateTypingStatus(
        chatId: _chat.id,
        userId: _currentUserId,
        isTyping: isTyping,
      );
    } catch (error) {
      _errorMessage = error.toString();
      _safeNotify();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    _isBusy = true;
    _errorMessage = null;
    _safeNotify();

    try {
      await action();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isBusy = false;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _typingDebounce?.cancel();
    unawaited(setTyping(false));
    super.dispose();
  }
}
