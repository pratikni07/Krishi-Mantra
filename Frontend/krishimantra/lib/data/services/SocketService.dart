import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/app_logger.dart';
import 'UserService.dart';

/// Socket connection state
enum SocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Socket Service with improved lifecycle management
/// Properly handles app lifecycle and connection states
class SocketService with WidgetsBindingObserver {
  // Singleton pattern
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal() {
    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);
  }

  final UserService _userService = UserService();

  // Socket instance
  IO.Socket? socket;
  SocketConnectionState _connectionState = SocketConnectionState.disconnected;
  int _reconnectionAttempts = 0;
  static const int _maxReconnectionAttempts = 5;
  Timer? _reconnectionTimer;
  Timer? _connectionCheckTimer;
  Timer? _heartbeatTimer;
  bool _isAppActive = true;
  bool _isDisposed = false;

  // Stream controllers for different events
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _onlineStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<SocketConnectionState>.broadcast();
  final _groupController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _deliveryStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _readReceiptController = StreamController<Map<String, dynamic>>.broadcast();
  final _aiMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _aiTypingController = StreamController<Map<String, dynamic>>.broadcast();
  final _aiAnalyzingController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageLimitController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get onlineStatusStream => _onlineStatusController.stream;
  Stream<SocketConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<Map<String, dynamic>> get groupStream => _groupController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<Map<String, dynamic>> get deliveryStatusStream => _deliveryStatusController.stream;
  Stream<Map<String, dynamic>> get readReceiptStream => _readReceiptController.stream;
  Stream<Map<String, dynamic>> get aiMessageStream => _aiMessageController.stream;
  Stream<Map<String, dynamic>> get aiTypingStream => _aiTypingController.stream;
  Stream<Map<String, dynamic>> get aiAnalyzingStream => _aiAnalyzingController.stream;
  Stream<Map<String, dynamic>> get messageLimitStream => _messageLimitController.stream;
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  // Getters
  bool get isConnected => _connectionState == SocketConnectionState.connected;
  bool get isReconnecting => _connectionState == SocketConnectionState.reconnecting;
  SocketConnectionState get connectionState => _connectionState;

  // Lifecycle management
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResume();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _handleAppPause();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _handleAppDetach();
        break;
    }
  }

  void _handleAppResume() {
    logger.d('App resumed, checking socket connection', tag: 'Socket');
    _isAppActive = true;
    if (!isConnected && !_isDisposed) {
      _scheduleReconnection(immediate: true);
    }
    _startHeartbeat();
  }

  void _handleAppPause() {
    logger.d('App paused, pausing heartbeat', tag: 'Socket');
    _isAppActive = false;
    _stopHeartbeat();
    // Don't disconnect immediately - allow background operation for a while
  }

  void _handleAppDetach() {
    logger.d('App detached, disconnecting socket', tag: 'Socket');
    _isAppActive = false;
    _stopHeartbeat();
    disconnect();
  }

  void _setConnectionState(SocketConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      _connectionStateController.add(state);
      logger.d('Socket state changed to: $state', tag: 'Socket');
    }
  }

  Future<void> initialize() async {
    if (_isDisposed) {
      logger.w('Cannot initialize disposed socket service', tag: 'Socket');
      return;
    }

    try {
      _setConnectionState(SocketConnectionState.connecting);

      final user = await _userService.getUser();
      if (user == null) {
        throw Exception('User not found');
      }

      final socketUrl = ApiConstants.socketUrl;
      logger.d('Initializing socket connection to: $socketUrl', tag: 'Socket');

      // Close existing socket if there is one
      await _cleanupSocket();

      socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableReconnection()
            .setReconnectionAttempts(_maxReconnectionAttempts)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setAuth({'userId': user.id, 'token': user.token})
            .setTimeout(15000)
            .setExtraHeaders({'Authorization': 'Bearer ${user.token}'})
            .build(),
      );

      _setupSocketListeners();

      // Wait for connection
      final connected = await _waitForConnection();
      if (!connected) {
        throw Exception('Failed to establish socket connection');
      }

      _startHeartbeat();
      _startConnectionHealthCheck();

    } catch (e, stack) {
      logger.e('Socket initialization error', tag: 'Socket', error: e, stackTrace: stack);
      _setConnectionState(SocketConnectionState.error);
      _errorController.add('Initialization error: $e');
      rethrow;
    }
  }

  Future<void> _cleanupSocket() async {
    _stopHeartbeat();
    _connectionCheckTimer?.cancel();
    _reconnectionTimer?.cancel();

    if (socket != null) {
      socket!.clearListeners();
      socket!.disconnect();
      socket!.dispose();
      socket = null;
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (isConnected && _isAppActive) {
        socket?.emit('heartbeat', {'timestamp': DateTime.now().toIso8601String()});
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _startConnectionHealthCheck() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (socket != null && !socket!.connected && !isReconnecting && _isAppActive) {
        logger.d('Connection health check failed, reconnecting', tag: 'Socket');
        _scheduleReconnection();
      }
    });
  }

  Future<bool> _waitForConnection({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      if (socket == null) return false;

      await Future.delayed(const Duration(milliseconds: 500));

      if (!socket!.connected) {
        socket!.connect();

        final completer = Completer<bool>();

        void onConnectHandler(_) {
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        }

        void onErrorHandler(error) {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        }

        socket!.once('connect', onConnectHandler);
        socket!.once('connect_error', onErrorHandler);

        final timer = Timer(timeout, () {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        });

        final result = await completer.future;
        timer.cancel();
        return result;
      }

      return socket!.connected;
    } catch (e) {
      logger.e('Wait for connection error', tag: 'Socket', error: e);
      return false;
    }
  }

  void _setupSocketListeners() {
    socket?.onConnect((_) {
      logger.i('Socket connected', tag: 'Socket');
      _setConnectionState(SocketConnectionState.connected);
      _reconnectionAttempts = 0;
      _reconnectionTimer?.cancel();
    });

    socket?.onDisconnect((_) {
      logger.w('Socket disconnected', tag: 'Socket');
      _setConnectionState(SocketConnectionState.disconnected);

      if (_isAppActive && !_isDisposed) {
        _scheduleReconnection();
      }
    });

    socket?.onError((error) {
      logger.e('Socket error', tag: 'Socket', error: error);
      _errorController.add('Socket error: $error');
    });

    socket?.onConnectError((error) {
      logger.e('Socket connection error', tag: 'Socket', error: error);
      _setConnectionState(SocketConnectionState.error);
      _errorController.add('Connection error: $error');
      _scheduleReconnection();
    });

    // Chat events
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

    // AI Chat events
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

    // Notification events (from notification-service WebSocket)
    socket?.on('notification', (data) {
      if (data is Map) {
        _notificationController.add(Map<String, dynamic>.from(data));
      }
    });

    socket?.on('notification:new', (data) {
      if (data is Map) {
        _notificationController.add(Map<String, dynamic>.from(data));
      }
    });
  }

  void _scheduleReconnection({bool immediate = false}) {
    if (_isDisposed || isReconnecting || _reconnectionAttempts >= _maxReconnectionAttempts) {
      if (_reconnectionAttempts >= _maxReconnectionAttempts) {
        logger.w('Max reconnection attempts reached', tag: 'Socket');
        _setConnectionState(SocketConnectionState.error);
      }
      return;
    }

    _setConnectionState(SocketConnectionState.reconnecting);
    _reconnectionAttempts++;

    _reconnectionTimer?.cancel();

    // Exponential backoff
    final delay = immediate
        ? Duration.zero
        : Duration(seconds: (2 * _reconnectionAttempts).clamp(2, 30));

    logger.d('Scheduling reconnection attempt $_reconnectionAttempts in ${delay.inSeconds}s', tag: 'Socket');

    _reconnectionTimer = Timer(delay, () async {
      if (!isConnected && _isAppActive && !_isDisposed) {
        await forceConnect();
      }
    });
  }

  bool isSocketConnected() => socket?.connected ?? false;

  Future<bool> forceConnect() async {
    if (_isDisposed) return false;

    try {
      if (socket == null) {
        await initialize();
        return isConnected;
      }

      if (!socket!.connected) {
        socket!.disconnect();
        await Future.delayed(const Duration(milliseconds: 300));
        socket!.connect();
      } else {
        return true;
      }

      final completer = Completer<bool>();

      void onConnect(_) {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }

      void onConnectError(error) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      }

      socket?.once('connect', onConnect);
      socket?.once('connect_error', onConnectError);

      final timeout = Timer(const Duration(seconds: 8), () {
        if (!completer.isCompleted) {
          completer.complete(false);
          _errorController.add('Socket connection timeout');
        }
      });

      final result = await completer.future;
      timeout.cancel();

      socket?.off('connect', onConnect);
      socket?.off('connect_error', onConnectError);

      if (result) {
        _setConnectionState(SocketConnectionState.connected);
      }

      return result;
    } catch (e) {
      logger.e('Force connect error', tag: 'Socket', error: e);
      _errorController.add('Connection error: $e');
      return false;
    }
  }

  Future<bool> checkNetworkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<bool> _sendRequest(
    String event,
    Map<String, dynamic> payload, {
    Duration timeoutDuration = const Duration(seconds: 10),
  }) async {
    if (!isConnected) {
      final reconnected = await forceConnect();
      if (!reconnected) {
        _errorController.add('Cannot send request: Socket connection failed');
        return false;
      }
    }

    try {
      final completer = Completer<bool>();

      final timer = Timer(timeoutDuration, () {
        if (!completer.isCompleted) {
          completer.complete(false);
          _errorController.add('Server did not respond. Check your connection and try again.');
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

  Future<bool> sendMessage(String chatId, Map<String, dynamic> messageData) async {
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

  Future<Map<String, dynamic>> createDirectChat(String participantId, String participantName) async {
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

      // Listen for the response event (server uses emit, not ack callback)
      void onResponse(dynamic data) {
        if (!completer.isCompleted && data != null) {
          completer.complete(Map<String, dynamic>.from(data as Map));
        }
      }

      socket?.once('chat:create:response', onResponse);
      socket?.emit('chat:create:direct', chatData);

      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          socket?.off('chat:create:response', onResponse);
          throw Exception('Chat creation timeout');
        },
      );
    } catch (e) {
      _errorController.add('Failed to create chat: $e');
      rethrow;
    }
  }

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

  void markMessagesAsRead(String chatId, List<String> messageIds) {
    if (isConnected) {
      socket?.emit('message:read', {
        'chatId': chatId,
        'messageIds': messageIds,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<Map<String, dynamic>> createGroup(
    String name,
    String description,
    List<Map<String, String>> participants,
  ) async {
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
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Group creation timeout'),
      );
    } catch (e) {
      _errorController.add('Failed to create group: $e');
      rethrow;
    }
  }

  void addGroupParticipants(String groupId, List<Map<String, String>> participants) {
    if (isConnected) {
      socket?.emit('group:add_participants', {
        'groupId': groupId,
        'participants': participants,
      });
    }
  }

  void updatePresence(String status) {
    if (isConnected) {
      socket?.emit('presence:update', {'status': status});
    }
  }

  void connect() {
    socket?.connect();
  }

  void disconnect() {
    _stopHeartbeat();
    socket?.disconnect();
    _setConnectionState(SocketConnectionState.disconnected);
  }

  Future<bool> sendAIMessage(String chatId, Map<String, dynamic> messageData) async {
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
          'weather': messageData['weather'] ?? {'temperature': 25, 'humidity': 60},
          'userId': user.id,
          'userName': '${user.firstName} ${user.lastName}'.trim(),
          'userProfilePhoto': user.image,
        },
        timeoutDuration: const Duration(seconds: 15),
      );
    } catch (e) {
      _errorController.add('Failed to prepare AI message: $e');
      return false;
    }
  }

  Future<bool> analyzeImage(String chatId, Map<String, dynamic> analysisData) async {
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
        const Duration(seconds: 30),
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

  Future<void> getMessageLimitInfo() async {
    if (!isSocketConnected()) await forceConnect();
    socket?.emit('ai:limit:info');
  }

  void dispose() {
    logger.i('Disposing socket service', tag: 'Socket');
    _isDisposed = true;

    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Cancel timers
    _reconnectionTimer?.cancel();
    _connectionCheckTimer?.cancel();
    _stopHeartbeat();

    // Disconnect and dispose socket
    socket?.clearListeners();
    socket?.disconnect();
    socket?.dispose();
    socket = null;

    // Do NOT close broadcast StreamControllers in a singleton.
    // Closing them permanently breaks the singleton since
    // StreamControllers cannot be reopened after close().
  }

  /// Reset the service for re-initialization (e.g., after logout + re-login)
  void reset() {
    _isDisposed = false;
    _reconnectionAttempts = 0;
  }
}
