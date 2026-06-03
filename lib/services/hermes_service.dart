import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/connection_settings.dart';
import 'notification_service.dart';

enum HermesConnectionState { idle, connecting, connected, disconnected, error }

class ApprovalRequest {
  final String sessionId;
  final String requestId;
  final String message;
  final String type; // 'approval', 'clarify', 'sudo', 'secret'

  const ApprovalRequest({
    required this.sessionId,
    required this.requestId,
    required this.message,
    required this.type,
  });
}

class HermesService extends ChangeNotifier {
  WebSocket? _ws;
  StreamSubscription? _sub;
  ConnectionSettings? _settings;

  HermesConnectionState _connectionState = HermesConnectionState.idle;
  String? _sessionId;
  String? _errorMessage;
  int _reqId = 0;

  final _pendingRequests = <String, Completer<dynamic>>{};
  final _messages = <ChatMessage>[];
  final _approvalRequests = <ApprovalRequest>[];

  // Active streaming message
  ChatMessage? _streamingMessage;

  HermesConnectionState get connectionState => _connectionState;
  String? get sessionId => _sessionId;
  String? get errorMessage => _errorMessage;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ApprovalRequest> get approvalRequests =>
      List.unmodifiable(_approvalRequests);
  bool get isConnected => _connectionState == HermesConnectionState.connected;
  bool get isBusy => _streamingMessage != null;

  Future<void> connect(ConnectionSettings settings) async {
    if (_connectionState == HermesConnectionState.connecting ||
        _connectionState == HermesConnectionState.connected) {
      await disconnect();
    }

    _settings = settings;
    _setState(HermesConnectionState.connecting);
    _errorMessage = null;

    try {
      _ws = await WebSocket.connect(
        settings.wsUrl,
        headers: {
          // ngrok free tier blocks non-browser WebSocket upgrades with 403.
          // This header bypasses the interstitial — harmless on other servers.
          'ngrok-skip-browser-warning': 'true',
          'User-Agent': 'HermesIOS/1.0',
        },
      );
      _ws!.pingInterval = const Duration(seconds: 20);

      _sub = _ws!.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      _errorMessage = e.toString();
      _setState(HermesConnectionState.error);
    }
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    await _ws?.close();
    _sub = null;
    _ws = null;
    _sessionId = null;
    _streamingMessage = null;
    _pendingRequests.forEach((_, c) => c.completeError('disconnected'));
    _pendingRequests.clear();
    _setState(HermesConnectionState.disconnected);
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      _dispatch(msg);
    } catch (e) {
      debugPrint('WS parse error: $e');
    }
  }

  void _onError(dynamic error) {
    _errorMessage = error.toString();
    _setState(HermesConnectionState.error);
  }

  void _onDone() {
    if (_connectionState != HermesConnectionState.disconnected) {
      _setState(HermesConnectionState.disconnected);
    }
  }

  void _dispatch(Map<String, dynamic> msg) {
    final id = msg['id'] as String?;

    // JSON-RPC response
    if (id != null && _pendingRequests.containsKey(id)) {
      final completer = _pendingRequests.remove(id)!;
      final error = msg['error'];
      if (error != null) {
        completer.completeError(
            (error as Map<String, dynamic>)['message'] ?? 'rpc error');
      } else {
        completer.complete(msg['result']);
      }
      return;
    }

    // Event notification
    if (msg['method'] == 'event') {
      final params = msg['params'] as Map<String, dynamic>? ?? {};
      final type = params['type'] as String? ?? '';
      final payload = params['payload'] as Map<String, dynamic>? ?? {};
      final evtSessionId = params['session_id'] as String?;
      _handleEvent(type, payload, evtSessionId);
    }
  }

  void _handleEvent(
      String type, Map<String, dynamic> payload, String? evtSessionId) {
    switch (type) {
      case 'gateway.ready':
        _setState(HermesConnectionState.connected);
        _createSession();
        break;

      case 'session.info':
        if (evtSessionId != null && _sessionId == null) {
          _sessionId = evtSessionId;
          notifyListeners();
        }
        break;

      case 'message.start':
        _streamingMessage = ChatMessage(
          id: evtSessionId ?? _generateId(),
          role: MessageRole.assistant,
          text: '',
          status: MessageStatus.streaming,
        );
        _messages.add(_streamingMessage!);
        notifyListeners();
        break;

      case 'message.delta':
        final text = payload['text'] as String? ?? '';
        if (_streamingMessage != null) {
          _streamingMessage!.text += text;
          notifyListeners();
        }
        break;

      case 'thinking.delta':
      case 'reasoning.delta':
        final text = payload['text'] as String? ?? '';
        if (_streamingMessage != null) {
          _streamingMessage!.thinking =
              (_streamingMessage!.thinking ?? '') + text;
          notifyListeners();
        }
        break;

      case 'message.complete':
        if (_streamingMessage != null) {
          _streamingMessage!.status = MessageStatus.complete;
          _streamingMessage = null;
          notifyListeners();
        }
        break;

      case 'status.update':
        final text = payload['text'] as String? ??
            payload['status'] as String? ??
            '';
        if (_streamingMessage != null && text.isNotEmpty) {
          _streamingMessage!.statusText = text;
          notifyListeners();
        }
        break;

      case 'tool.start':
        _handleToolStart(payload, evtSessionId);
        break;

      case 'tool.progress':
        _handleToolProgress(payload);
        break;

      case 'tool.complete':
        _handleToolComplete(payload);
        break;

      case 'approval.request':
      case 'clarify.request':
      case 'sudo.request':
      case 'secret.request':
        _handleApprovalRequest(type, payload, evtSessionId);
        break;

      case 'error':
        final errText =
            payload['message'] as String? ?? payload['text'] as String? ?? 'Error';
        _addSystemMessage('Error: $errText');
        if (_streamingMessage != null) {
          _streamingMessage!.status = MessageStatus.error;
          _streamingMessage = null;
        }
        notifyListeners();
        break;
    }
  }

  void _handleToolStart(Map<String, dynamic> payload, String? evtSessionId) {
    final toolId = payload['tool_id'] as String? ?? _generateId();
    final name = payload['tool'] as String? ??
        payload['name'] as String? ??
        'unknown';
    final input = payload['input'] as String? ??
        (payload['args'] != null ? jsonEncode(payload['args']) : '');
    final entry = ToolCallEntry(
      id: toolId,
      name: name,
      input: input,
      isRunning: true,
    );
    if (_streamingMessage == null) {
      _streamingMessage = ChatMessage(
        id: evtSessionId ?? _generateId(),
        role: MessageRole.assistant,
        text: '',
        status: MessageStatus.streaming,
      );
      _messages.add(_streamingMessage!);
    }
    _streamingMessage!.toolCalls.add(entry);
    notifyListeners();
  }

  void _handleToolProgress(Map<String, dynamic> payload) {
    final toolId = payload['tool_id'] as String?;
    if (toolId == null || _streamingMessage == null) return;
    final entry = _streamingMessage!.toolCalls
        .where((t) => t.id == toolId)
        .firstOrNull;
    if (entry != null) {
      final text = payload['text'] as String? ?? '';
      entry.output = (entry.output ?? '') + text;
      notifyListeners();
    }
  }

  void _handleToolComplete(Map<String, dynamic> payload) {
    final toolId = payload['tool_id'] as String?;
    if (toolId == null || _streamingMessage == null) return;
    final entry = _streamingMessage!.toolCalls
        .where((t) => t.id == toolId)
        .firstOrNull;
    if (entry != null) {
      entry.isRunning = false;
      entry.isComplete = true;
      final result = payload['result'] as String? ??
          (payload['output'] != null
              ? jsonEncode(payload['output'])
              : null);
      if (result != null && entry.output == null) {
        entry.output = result;
      }
      notifyListeners();
    }
  }

  void _handleApprovalRequest(
      String type, Map<String, dynamic> payload, String? evtSessionId) {
    final requestId = payload['request_id'] as String? ?? _generateId();
    final message = payload['message'] as String? ??
        payload['prompt'] as String? ??
        payload['text'] as String? ??
        'Permission required';
    final req = ApprovalRequest(
      sessionId: evtSessionId ?? _sessionId ?? '',
      requestId: requestId,
      message: message,
      type: type.replaceAll('.request', ''),
    );
    _approvalRequests.add(req);
    notifyListeners();

    // Fire a local notification so the user knows even if the app is in background
    final notifTitle = _approvalTitle(req.type);
    NotificationService().showApproval(
      title: notifTitle,
      body: message.length > 120 ? '${message.substring(0, 117)}…' : message,
      id: 1000 + _approvalRequests.length,
    );
  }

  String _approvalTitle(String type) {
    switch (type) {
      case 'sudo':
        return '🔐 Hermes needs elevated permission';
      case 'secret':
        return '🔑 Hermes needs a secret value';
      case 'clarify':
        return '❓ Hermes needs clarification';
      default:
        return '✅ Hermes needs your approval';
    }
  }

  Future<void> _createSession() async {
    try {
      final result = await _request('session.create', {});
      if (result is Map<String, dynamic>) {
        _sessionId = result['session_id'] as String?;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('session.create failed: $e');
    }
  }

  Future<void> sendMessage(String text) async {
    if (!isConnected || _sessionId == null || text.trim().isEmpty) return;

    // Add user message immediately
    _messages.add(ChatMessage(
      id: _generateId(),
      role: MessageRole.user,
      text: text.trim(),
    ));
    notifyListeners();

    try {
      await _request('prompt.submit', {
        'session_id': _sessionId!,
        'text': text.trim(),
      });
    } catch (e) {
      _addSystemMessage('Send failed: $e');
    }
  }

  Future<void> respondToApproval(
      ApprovalRequest req, bool approved, {String? text}) async {
    _approvalRequests.remove(req);
    notifyListeners();

    try {
      await _request('approval.respond', {
        'session_id': req.sessionId,
        'request_id': req.requestId,
        'approved': approved,
        'text': text ?? '',
      });
    } catch (e) {
      debugPrint('approval.respond failed: $e');
    }
  }

  Future<void> interruptSession() async {
    if (_sessionId == null) return;
    try {
      await _request('session.interrupt', {'session_id': _sessionId!});
    } catch (e) {
      debugPrint('interrupt failed: $e');
    }
  }

  Future<void> reconnect() async {
    if (_settings != null) {
      _messages.clear();
      _approvalRequests.clear();
      notifyListeners();
      await connect(_settings!);
    }
  }

  Future<dynamic> _request(String method, Map<String, dynamic> params) {
    if (_ws == null) {
      return Future.error('not connected');
    }
    final id = 'r${++_reqId}';
    final completer = Completer<dynamic>();
    _pendingRequests[id] = completer;
    _ws!.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    }));
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingRequests.remove(id);
        throw TimeoutException('request timed out: $method');
      },
    );
  }

  void _addSystemMessage(String text) {
    _messages.add(ChatMessage(
      id: _generateId(),
      role: MessageRole.system,
      text: text,
    ));
    notifyListeners();
  }

  void _setState(HermesConnectionState state) {
    _connectionState = state;
    notifyListeners();
  }

  String _generateId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(16);

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
