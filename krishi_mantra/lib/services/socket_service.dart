import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  IO.Socket? _socket;
  final String _serverUrl = 'http://localhost:3004';
  final String userId;
  Function(dynamic)? onMessageReceived;
  final String userName = "Pratik Nikat";
  Function(dynamic)? onChatCreated;
  Function(dynamic)? onTypingUpdate;
  Function(dynamic)? onUserStatus;

  SocketService({
    required this.userId,
    this.onMessageReceived,
    this.onChatCreated,
    this.onTypingUpdate,
    this.onUserStatus,
  });

  void connect() {
    _socket = IO.io(
      _serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'userId': userId})
          .disableAutoConnect()
          .build(),
    );

    _socket?.connect();

    _socket?.onConnect((_) {
      print('Socket connected');
    });

    _socket?.on('message:received', (data) {
      onMessageReceived?.call(data);
    });

    _socket?.on('chat:new', (data) {
      onChatCreated?.call(data);
    });

    _socket?.on('typing:update', (data) {
      onTypingUpdate?.call(data);
    });

    _socket?.on('user:status', (data) {
      onUserStatus?.call(data);
    });

    _socket?.onConnectError((error) {
      print('Socket connection error: $error');
    });

    _socket?.onError((error) {
      print('Socket error: $error');
    });
  }

  // Rest of the methods remain the same
  void disconnect() {
    _socket?.disconnect();
  }

  void sendMessage(String chatId, String content, {String? mediaUrl}) {
    _socket?.emit('message:send', {
      'chatId': chatId,
      'message': {
        'content': content,
        'mediaType': mediaUrl != null ? _getMediaType(mediaUrl) : 'text',
        'mediaUrl': mediaUrl,
      },
      'senderName': userName,
    });
  }

  void startTyping(String chatId) {
    _socket?.emit('typing:start', {'chatId': chatId});
  }

  void stopTyping(String chatId) {
    _socket?.emit('typing:stop', {'chatId': chatId});
  }

  void createDirectChat(String participantId, String participantName) {
    _socket?.emit('chat:create:direct', {
      'userId': userId,
      'userName': userName,
      'participantId': participantId,
      'participantName': participantName,
    });
  }

  void markMessageAsRead(String chatId, List<String> messageIds) {
    _socket?.emit('message:read', {
      'chatId': chatId,
      'messageIds': messageIds,
    });
  }

  String _getMediaType(String url) {
    final extension = url.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) return 'image';
    if (['mp4', 'mov', 'avi'].contains(extension)) return 'video';
    return 'file';
  }
}
