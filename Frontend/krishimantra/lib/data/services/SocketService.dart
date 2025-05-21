// ignore_for_file: unused_element

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

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
  Timer? _reconnectionTimer;
  Timer? _connectionCheckTimer;

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

  // Add these new stream controllers for AI chat events
  final _aiMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _aiTypingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _aiAnalyzingController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Message limit controller
  final _messageLimitController =
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

  // Add getters for the new streams
  Stream<Map<String, dynamic>> get aiMessageStream =>
      _aiMessageController.stream;
  Stream<Map<String, dynamic>> get aiTypingStream => _aiTypingController.stream;
  Stream<Map<String, dynamic>> get aiAnalyzingStream =>
      _aiAnalyzingController.stream;
  Stream<Map<String, dynamic>> get messageLimitStream =>
      _messageLimitController.stream;

  // Helper method to create a stream from a socket event
  Stream<Map<String, dynamic>> _createStream(String eventName) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    socket?.on(eventName, (data) {
      if (data is Map) {
        controller.add(Map<String, dynamic>.from(data));
      }
    });

    return controller.stream;
  }

  Future<void> initialize() async {
    try {
      final user = await _userService.getUser();
      if (user == null) throw Exception('User not found');

      // Use the correct WebSocket URL from your configuration
      final socketUrl = ApiConstants.socketUrl;

      // Close existing socket if there is one
      socket?.dispose();

      socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .setAuth({'userId': user.id})
            .setTimeout(ApiConstants.connectionTimeout)
            .setExtraHeaders({'Authorization': 'Bearer ${user.token}'})
            .build(),
      );

      setupSocketListeners();

      // Check connection with timeout
      bool connected = await _waitForConnection();
      if (!connected) {
        throw Exception('Failed to establish socket connection');
      }

      // Start periodic connection check
      _startConnectionHealthCheck();
    } catch (e) {
      _errorController.add('Initialization error: $e');
      rethrow;
    }
  }

  void _startConnectionHealthCheck() {
    // Cancel existing timer if any
    _connectionCheckTimer?.cancel();

    // Check connection every 30 seconds
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (socket != null && !socket!.connected && !isReconnecting) {
        handleReconnection();
      }
    });
  }

  Future<bool> _waitForConnection() async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      if (!socket!.connected) {
        socket!.connect();

        // Create a completer to handle the connection state
        final completer = Completer<bool>();

        // Setup one-time connection listener
        void onConnectHandler(_) {
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        }

        // Setup error handler
        void onErrorHandler(error) {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        }

        // Add connection listeners
        socket!.once('connect', onConnectHandler);
        socket!.once('connect_error', onErrorHandler);

        // Setup timeout
        Timer(const Duration(seconds: 5), () {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        });

        // Wait for result and cleanup
        final result = await completer.future;
        return result;
      }
      return socket!.connected;
    } catch (e) {
      return false;
    }
  }

  void setupSocketListeners() {
    socket?.onConnect((_) async {
      try {
        isConnected = true;
        isReconnecting = false;
        reconnectionAttempts = 0;
        _connectionStateController.add(true);

        // Cancel any pending reconnection attempts
        _reconnectionTimer?.cancel();
      } catch (e) {
        _errorController.add('Connection error: $e');
      }
    });

    socket?.onDisconnect((_) {
      isConnected = false;
      _connectionStateController.add(false);

      // Try to reconnect if not already reconnecting
      if (!isReconnecting) {
        handleReconnection();
      }
    });

    socket?.onError((error) {
      _errorController.add('Socket error: $error');
    });

    socket?.onConnectError((error) {
      _errorController.add('Connection error: $error');
      handleReconnection();
    });

    // Chat related events
    socket?.on('message:received', (data) {
      if (data is Map) {
        _messageController.add(Map<String, dynamic>.from(data));
      }
    });

    socket?.on('message:delivered', (data) {
      if (data is Map) {
        _deliveryStatusController.add(Map<String, dynamic>.from(data));
      }
    });

    socket?.on('message:read:update', (data) {
      if (data is Map) {
        _readReceiptController.add(Map<String, dynamic>.from(data));
      }
    });

    socket?.on('chat:create:response', (data) {});

    socket?.on('chat:new', (data) {});

    // Typing events
    socket?.on('typing:update', (data) {
      if (data is Map) {
        _typingController.add(Map<String, dynamic>.from(data));
      }
    });

    // User status events
    socket?.on('user:status', (data) {
      if (data is Map) {
        _onlineStatusController.add(Map<String, dynamic>.from(data));
      }
    });

    // Group events
    socket?.on('group:new', (data) {
      if (data is Map) {
        _groupController.add(Map<String, dynamic>.from(data));
      }
    });

    socket?.on('group:added', (data) {
      if (data is Map) {
        _groupController.add(Map<String, dynamic>.from(data));
      }
    });

    socket?.on('group:participants_updated', (data) {
      if (data is Map) {
        _groupController.add(Map<String, dynamic>.from(data));
      }
    });

    // AI Chat related events
    socket?.on('ai:message:received', (data) {
      if (data is Map) {
        _aiMessageController.add(Map<String, dynamic>.from(data));
      }
    });

    socket?.on('ai:typing', (data) {
      if (data is Map) {
        _aiTypingController.add(Map<String, dynamic>.from(data));
      }
    });

    socket?.on('ai:analyzing', (data) {
      if (data is Map) {
        _aiAnalyzingController.add(Map<String, dynamic>.from(data));
      }
    });

    socket?.on('ai:image:analyzed', (data) {
      if (data is Map) {
        _aiMessageController.add(Map<String, dynamic>.from(data));
      }
    });

    // Message limit events
    socket?.on('ai:limit:info', (data) {
      if (data is Map) {
        _messageLimitController.add(Map<String, dynamic>.from(data));
      }
    });

    socket?.on('ai:limit:reached', (data) {
      if (data is Map) {
        _messageLimitController.add(Map<String, dynamic>.from(data));
      }
    });
  }

  void handleReconnection() {
    if (isReconnecting || reconnectionAttempts >= maxReconnectionAttempts)
      return;

    isReconnecting = true;
    reconnectionAttempts++;

    // Cancel any existing timer
    _reconnectionTimer?.cancel();

    // Use exponential backoff for reconnection attempts
    final delay = Duration(seconds: 2 * reconnectionAttempts);

    _reconnectionTimer = Timer(delay, () {
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
      // Check if we need to initialize
      if (socket == null) {
        try {
          await initialize();
        } catch (initError) {
          _errorController.add('Failed to initialize socket: $initError');
          return false;
        }
      }
      // Try reconnecting if disconnected
      else if (!socket!.connected) {
        // Since we can't use 'connecting' property, we'll just try to disconnect first
        // to ensure a clean connection attempt
        socket!.disconnect();
        await Future.delayed(Duration(milliseconds: 500));

        // Now try connecting
        socket!.connect();
      } else {
        return true;
      }

      // Wait for connection with improved timeout handling
      Completer<bool> connectionCompleter = Completer();

      // Add temporary connection listener
      void onConnect(_) {
        if (!connectionCompleter.isCompleted) {
          connectionCompleter.complete(true);
        }
      }

      void onConnectError(error) {
        if (!connectionCompleter.isCompleted) {
          connectionCompleter.complete(false);
        }
      }

      socket?.once('connect', onConnect);
      socket?.once('connect_error', onConnectError);

      // Setup timeout
      Timer timeout = Timer(Duration(seconds: 8), () {
        if (!connectionCompleter.isCompleted) {
          connectionCompleter.complete(false);
          _errorController.add('Socket connection timeout');
        }
      });

      bool result = await connectionCompleter.future;
      timeout.cancel();

      // Remove temporary listeners
      socket?.off('connect', onConnect);
      socket?.off('connect_error', onConnectError);

      isConnected = result;

      if (result) {
        _connectionStateController.add(true);
      }

      return result;
    } catch (e) {
      _errorController.add('Connection error: $e');
      return false;
    }
  }

  // Message methods
  Future<bool> checkNetworkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Generic method for socket requests with acknowledgement
  Future<bool> _sendRequest(String event, Map<String, dynamic> payload,
      {Duration timeoutDuration = const Duration(seconds: 10)}) async {
    // Check and ensure socket connection
    if (!isConnected) {
      bool reconnected = await forceConnect();
      if (!reconnected) {
        _errorController.add('Cannot send request: Socket connection failed');
        return false;
      }
    }

    try {
      final completer = Completer<bool>();

      Timer timer = Timer(timeoutDuration, () {
        if (!completer.isCompleted) {
          completer.complete(false);
          _errorController.add(
              'Server did not respond. Check your connection and try again.');
        }
      });

      try {
        socket?.emitWithAck(event, payload, ack: (data) {
          timer.cancel();

          if (data == null) {
            if (!completer.isCompleted) {
              completer.complete(false);
              _errorController.add('Server returned an invalid response');
            }
            return;
          }

          if (data is Map && data.containsKey('error')) {
            if (!completer.isCompleted) {
              completer.complete(false);
              _errorController.add('Server error: ${data['error']}');
            }
            return;
          }

          if (!completer.isCompleted) {
            completer.complete(true);
          }
        });
      } catch (emitError) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
          _errorController.add('Failed to send request: $emitError');
        }
      }

      return await completer.future;
    } catch (e) {
      _errorController.add('Failed to send request: $e');
      return false;
    }
  }

  Future<bool> sendMessage(
      String chatId, Map<String, dynamic> messageData) async {
    try {
      final user = await _userService.getUser();
      if (user == null) {
        _errorController.add('User not authenticated');
        return false;
      }

      return _sendRequest('message:send', {
        'chatId': chatId,
        'content': messageData['content'],
        'mediaType': messageData['mediaType'] ?? 'text',
        'mediaUrl': messageData['mediaUrl'] ?? '',
        'userId': user.id,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _errorController.add('Failed to prepare message: $e');
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
      socket?.emit('typing:start', {
        'chatId': chatId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  void sendTypingStop(String chatId) {
    if (isConnected) {
      socket?.emit('typing:stop', {
        'chatId': chatId,
        'timestamp': DateTime.now().toIso8601String(),
      });
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
    // Cancel timers
    _reconnectionTimer?.cancel();
    _connectionCheckTimer?.cancel();

    // Disconnect and dispose socket
    socket?.disconnect();
    socket?.dispose();
    socket = null;

    // Close all stream controllers
    _messageController.close();
    _typingController.close();
    _onlineStatusController.close();
    _connectionStateController.close();
    _groupController.close();
    _errorController.close();
    _deliveryStatusController.close();
    _readReceiptController.close();
    _aiMessageController.close();
    _aiTypingController.close();
    _aiAnalyzingController.close();
    _messageLimitController.close();
  }

  // Add AI chat specific methods
  Future<bool> sendAIMessage(
      String chatId, Map<String, dynamic> messageData) async {
    try {
      final user = await _userService.getUser();
      if (user == null) {
        _errorController.add('User not authenticated for AI message');
        return false;
      }

      return _sendRequest(
          'ai:message:send',
          {
            'chatId': chatId,
            'message': messageData['content'],
            'preferredLanguage': messageData['preferredLanguage'] ?? 'en',
            'location': messageData['location'] ?? {'lat': 0, 'lon': 0},
            'weather':
                messageData['weather'] ?? {'temperature': 25, 'humidity': 60},
            'userId': user.id,
            'userName': '${user.firstName} ${user.lastName}'.trim(),
            'userProfilePhoto': user.image,
          },
          timeoutDuration: const Duration(seconds: 15));
    } catch (e) {
      _errorController.add('Failed to prepare AI message: $e');
      return false;
    }
  }

  Future<bool> analyzeImage(
      String chatId, Map<String, dynamic> analysisData) async {
    if (!isConnected) {
      await forceConnect();
      if (!isConnected) {
        _errorController.add('Socket not connected. Unable to analyze image.');
        return false;
      }
    }

    try {
      final completer = Completer<bool>();

      socket?.emitWithAck('ai:image:analyze', {
        'chatId': chatId,
        'imageBuffer': analysisData['imageBuffer'],
        'preferredLanguage': analysisData['preferredLanguage'],
        'location': analysisData['location'],
        'weather': analysisData['weather'],
      }, ack: (data) {
        if (data != null && !completer.isCompleted) {
          completer.complete(true);
        } else if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      return await completer.future.timeout(
        const Duration(seconds: 30), // Longer timeout for image analysis
        onTimeout: () {
          _errorController.add('Image analysis timeout');
          return false;
        },
      );
    } catch (e) {
      _errorController.add('Failed to analyze image: $e');
      return false;
    }
  }

  // Message limit events
  Future<void> getMessageLimitInfo() async {
    if (!isSocketConnected()) await forceConnect();
    socket?.emit('ai:limit:info');
  }
}
