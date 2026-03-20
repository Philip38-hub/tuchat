import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tuchat/models/chat.dart';
import 'package:tuchat/models/message.dart';
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
  final ImagePicker _imagePicker = ImagePicker();

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

  Future<void> pickAndSendMedia(MessageType type) async {
    final file = await _pickMedia(type);
    if (file == null) {
      return;
    }

    final bytes = await file.readAsBytes();
    final mimeType = _mimeTypeFor(type, file.name);
    await _run(() {
      return _chatService.sendMediaMessage(
        chat: _chat,
        senderId: _currentUserId,
        receiverId: _otherUserId,
        bytes: bytes,
        fileName: file.name,
        mimeType: mimeType,
        type: type,
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

  Future<XFile?> _pickMedia(MessageType type) {
    if (type == MessageType.video) {
      return _imagePicker.pickVideo(source: ImageSource.gallery);
    }

    return _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
  }

  String _mimeTypeFor(MessageType type, String fileName) {
    final normalized = fileName.toLowerCase();
    if (type == MessageType.video) {
      if (normalized.endsWith('.mov')) {
        return 'video/quicktime';
      }
      return 'video/mp4';
    }

    if (normalized.endsWith('.png')) {
      return 'image/png';
    }
    if (normalized.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}
