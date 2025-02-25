import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import 'dart:convert';

import '../../core/constants/api_constants.dart';
import 'UserService.dart';

class SocketService {
  // Singleton pattern
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  final UserService _userService = UserService();

  // Socket instance
  IO.Socket? socket;
  bool isConnected = false;
  bool isReconnecting = false;
  int reconnectionAttempts = 0;
  static const int maxReconnectionAttempts = 5;

  // Stream controllers for different events
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _onlineStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _groupController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _deliveryStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _readReceiptController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get onlineStatusStream =>
      _onlineStatusController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  Stream<Map<String, dynamic>> get groupStream => _groupController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<Map<String, dynamic>> get deliveryStatusStream =>
      _deliveryStatusController.stream;
  Stream<Map<String, dynamic>> get readReceiptStream =>
      _readReceiptController.stream;

  Future<void> initialize() async {
    if (socket != null && socket!.connected) {
      print('Socket already connected');
      return;
    }

    try {
      final user = await _userService.getUser();
      print('Initializing socket service...');

      if (user == null) {
        throw Exception('User not found. Please login first.');
      }

      socket = IO.io(
        ApiConstants.BASE_URL,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionAttempts(maxReconnectionAttempts)
            .setAuth({'userId': user.id})
            .setTimeout(ApiConstants.connectionTimeout)
            .setExtraHeaders({'Authorization': 'Bearer ${user.token}'})
            .build(),
      );

      setupSocketListeners();

      // Check if connection is successful after setup
      await Future.delayed(Duration(seconds: 2));
      if (!socket!.connected) {
        socket!.connect();
      }
    } catch (e, stackTrace) {
      print('Socket initialization error: $e');
      print('Stack trace: $stackTrace');
      _errorController.add('Initialization error: $e');
      rethrow;
    }
  }

  void setupSocketListeners() {
    socket?.onConnect((_) async {
      try {
        final user = await _userService.getUser();
        print('Socket connected successfully'); // Debug log
        print('Connected with user ID: ${user?.id}');
        isConnected = true;
        isReconnecting = false;
        reconnectionAttempts = 0;
        _connectionStateController.add(true);
      } catch (e) {
        print('Connection callback error: $e'); // Debug log
        _errorController.add('Connection error: $e');
      }
    });

    socket?.onDisconnect((_) {
      print('Socket disconnected. Was connected: $isConnected'); // Debug log
      isConnected = false;
      _connectionStateController.add(false);
    });

    socket?.onError((error) {
      print('Socket error details: $error'); // Debug log
      _errorController.add('Socket error: $error');
    });

    socket?.onConnectError((error) {
      print('Connection error details: $error'); // Debug log
      _errorController.add('Connection error: $error');
      handleReconnection();
    });

    // Chat related events
    socket?.on('message:received', (data) {
      _messageController.add(Map<String, dynamic>.from(data));
    });

    socket?.on('message:delivered', (data) {
      _deliveryStatusController.add(Map<String, dynamic>.from(data));
    });

    socket?.on('message:read:update', (data) {
      _readReceiptController.add(Map<String, dynamic>.from(data));
    });

    socket?.on('chat:create:response', (data) {
      print('New chat created: $data');
    });

    socket?.on('chat:new', (data) {
      print('Added to new chat: $data');
    });

    // Typing events
    socket?.on('typing:update', (data) {
      _typingController.add(Map<String, dynamic>.from(data));
    });

    // User status events
    socket?.on('user:status', (data) {
      _onlineStatusController.add(Map<String, dynamic>.from(data));
    });

    // Group events
    socket?.on('group:new', (data) {
      _groupController.add(Map<String, dynamic>.from(data));
    });

    socket?.on('group:added', (data) {
      _groupController.add(Map<String, dynamic>.from(data));
    });

    socket?.on('group:participants_updated', (data) {
      _groupController.add(Map<String, dynamic>.from(data));
    });
  }

  void handleReconnection() {
    if (isReconnecting || reconnectionAttempts >= maxReconnectionAttempts)
      return;

    isReconnecting = true;
    reconnectionAttempts++;

    Future.delayed(Duration(seconds: reconnectionAttempts * 2), () {
      if (!isConnected) {
        connect();
        isReconnecting = false;
      }
    });
  }

  bool isSocketConnected() {
    return socket?.connected ?? false;
  }

  Future<bool> forceConnect() async {
    try {
      print('Forcing socket connection...');
      if (socket == null) {
        await initialize();
      } else if (!socket!.connected) {
        socket?.connect();
      } else {
        return true; // Already connected
      }

      // Wait for connection with proper timeout
      Completer<bool> connectionCompleter = Completer();
      Timer timeout = Timer(Duration(seconds: 5), () {
        if (!connectionCompleter.isCompleted) {
          connectionCompleter.complete(false);
        }
      });

      // Add temporary connection listener
      void onConnect(_) {
        if (!connectionCompleter.isCompleted) {
          connectionCompleter.complete(true);
        }
      }

      socket?.onConnect(onConnect);

      bool result = await connectionCompleter.future;
      timeout.cancel();

      // Remove temporary listener to avoid duplicates
      socket?.off('connect', onConnect);

      isConnected = result;
      print('Force connect result - Connected: $result');
      return result;
    } catch (e) {
      print('Force connect error: $e');
      return false;
    }
  }

  // Message methods
  Future<bool> sendMessage(
      String chatId, Map<String, dynamic> messageData) async {
    if (!isConnected) {
      await forceConnect();
      if (!isConnected) {
        _errorController.add('Socket not connected. Unable to send message.');
        return false;
      }
    }

    try {
      final user = await _userService.getUser();
      final completer = Completer<bool>();

      // Add timeout to prevent hanging
      Timer(Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          completer.complete(false);
          _errorController.add('Message send timeout');
        }
      });

      socket?.emitWithAck('message:send', {
        'chatId': chatId,
        'content': messageData['content'],
        'mediaType': messageData['mediaType'] ?? 'text',
        'mediaUrl': messageData['mediaUrl'] ?? '',
      }, ack: (data) {
        if (data != null && !completer.isCompleted) {
          completer.complete(true);
        } else if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      return await completer.future;
    } catch (e) {
      _errorController.add('Failed to send message: $e');
      return false;
    }
  }

  // Chat methods
  Future<Map<String, dynamic>> createDirectChat(
      String participantId, String participantName) async {
    if (!isConnected) {
      throw Exception('Socket not connected');
    }

    try {
      final user = await _userService.getUser();
      final chatData = {
        'participantId': participantId,
        'participantName': participantName,
        'userId': user?.id,
        'userName': '${user?.firstName} ${user?.lastName}',
      };

      final completer = Completer<Map<String, dynamic>>();

      socket?.emitWithAck('chat:create:direct', chatData, ack: (data) {
        if (data != null) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.completeError('Failed to create chat');
        }
      });

      return await completer.future.timeout(
        Duration(seconds: 10),
        onTimeout: () => throw Exception('Chat creation timeout'),
      );
    } catch (e) {
      _errorController.add('Failed to create chat: $e');
      rethrow;
    }
  }

  // Typing methods
  void sendTypingStart(String chatId) {
    if (isConnected) {
      socket?.emit('typing:start', {'chatId': chatId});
    }
  }

  void sendTypingStop(String chatId) {
    if (isConnected) {
      socket?.emit('typing:stop', {'chatId': chatId});
    }
  }

  // Read receipt methods
  void markMessagesAsRead(String chatId, List<String> messageIds) {
    if (isConnected) {
      socket?.emit('message:read', {
        'chatId': chatId,
        'messageIds': messageIds,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  // Group methods
  Future<Map<String, dynamic>> createGroup(String name, String description,
      List<Map<String, String>> participants) async {
    if (!isConnected) {
      throw Exception('Socket not connected');
    }

    try {
      final user = await _userService.getUser();
      final groupData = {
        'name': name,
        'description': description,
        'adminId': user?.id,
        'participants': participants,
      };

      final completer = Completer<Map<String, dynamic>>();

      socket?.emitWithAck('group:create', groupData, ack: (data) {
        if (data != null) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.completeError('Failed to create group');
        }
      });

      return await completer.future.timeout(
        Duration(seconds: 10),
        onTimeout: () => throw Exception('Group creation timeout'),
      );
    } catch (e) {
      _errorController.add('Failed to create group: $e');
      rethrow;
    }
  }

  void addGroupParticipants(
      String groupId, List<Map<String, String>> participants) {
    if (isConnected) {
      socket?.emit('group:add_participants', {
        'groupId': groupId,
        'participants': participants,
      });
    }
  }

  // Presence methods
  void updatePresence(String status) {
    if (isConnected) {
      socket?.emit('presence:update', {'status': status});
    }
  }

  // Connection methods
  void connect() {
    socket?.connect();
  }

  void disconnect() {
    socket?.disconnect();
  }

  // Cleanup method
  void dispose() {
    socket?.dispose();
    _messageController.close();
    _typingController.close();
    _onlineStatusController.close();
    _connectionStateController.close();
    _groupController.close();
    _errorController.close();
    _deliveryStatusController.close();
    _readReceiptController.close();
  }
}
