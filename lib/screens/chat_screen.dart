import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/hermes_service.dart';
import '../theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/approval_sheet.dart';
import 'connect_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  bool _inputHasText = false;
  // Tracks whether an approval sheet is already showing (avoid stacking sheets)
  bool _approvalShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _inputCtrl.addListener(() {
      final has = _inputCtrl.text.isNotEmpty;
      if (has != _inputHasText) setState(() => _inputHasText = has);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<HermesService>();
      service.addListener(_onServiceUpdate);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final service = context.read<HermesService>();
    service.removeListener(_onServiceUpdate);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Called by the OS when the app moves between foreground/background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final service = context.read<HermesService>();
      // Reconnect if we were disconnected while in background
      if (service.connectionState == HermesConnectionState.disconnected ||
          service.connectionState == HermesConnectionState.error) {
        service.reconnect();
      }
      // Show any approval requests that arrived while in background
      _checkApprovalRequests();
    }
  }

  void _onServiceUpdate() {
    _scrollToBottom();
    _checkApprovalRequests();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _checkApprovalRequests() {
    if (_approvalShowing) return;
    final service = context.read<HermesService>();
    if (service.approvalRequests.isNotEmpty) {
      final req = service.approvalRequests.first;
      _showApprovalSheet(req);
    }
  }

  void _showApprovalSheet(ApprovalRequest req) {
    if (!mounted || _approvalShowing) return;
    _approvalShowing = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ApprovalSheet(
        request: req,
        onRespond: (approved, text) {
          Navigator.of(context).pop();
          context.read<HermesService>().respondToApproval(
                req,
                approved,
                text: text,
              );
        },
      ),
    ).whenComplete(() {
      _approvalShowing = false;
      // Show next pending approval if any
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkApprovalRequests());
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    FocusScope.of(context).unfocus();
    await context.read<HermesService>().sendMessage(text);
  }

  Future<void> _disconnect() async {
    await context.read<HermesService>().disconnect();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ConnectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HermesService>(
      builder: (context, service, _) {
        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: _buildAppBar(service),
          body: Column(
            children: [
              // Connection status banner
              if (service.connectionState != HermesConnectionState.connected)
                _buildStatusBanner(service),
              // Messages list
              Expanded(child: _buildMessageList(service)),
              // Input bar
              _buildInputBar(service),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(HermesService service) {
    final isConnected = service.connectionState == HermesConnectionState.connected;
    return AppBar(
      backgroundColor: AppTheme.surface,
      elevation: 0,
      titleSpacing: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child:
            const Icon(Icons.psychology, color: AppTheme.accent, size: 20),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hermes',
              style: AppTheme.termFont.copyWith(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isConnected
                      ? AppTheme.accentGreen
                      : AppTheme.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                isConnected ? 'connected' : service.connectionState.name,
                style: AppTheme.termFont.copyWith(
                    color: isConnected
                        ? AppTheme.accentGreen
                        : AppTheme.textMuted,
                    fontSize: 11),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (service.isBusy)
          IconButton(
            icon:
                const Icon(Icons.stop_circle_outlined, color: AppTheme.error),
            tooltip: 'Interrupt',
            onPressed: service.interruptSession,
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
          color: AppTheme.surfaceAlt,
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  const Icon(Icons.delete_sweep,
                      color: AppTheme.textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Text('Clear messages',
                      style: AppTheme.termFont
                          .copyWith(color: AppTheme.textPrimary)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'reconnect',
              child: Row(
                children: [
                  const Icon(Icons.refresh,
                      color: AppTheme.textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Text('Reconnect',
                      style: AppTheme.termFont
                          .copyWith(color: AppTheme.textPrimary)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'disconnect',
              child: Row(
                children: [
                  const Icon(Icons.link_off,
                      color: AppTheme.error, size: 18),
                  const SizedBox(width: 10),
                  Text('Disconnect',
                      style: AppTheme.termFont
                          .copyWith(color: AppTheme.error)),
                ],
              ),
            ),
          ],
          onSelected: (v) async {
            switch (v) {
              case 'clear':
                service.clearMessages();
                break;
              case 'reconnect':
                await service.reconnect();
                break;
              case 'disconnect':
                await _disconnect();
                break;
            }
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.border),
      ),
    );
  }

  Widget _buildStatusBanner(HermesService service) {
    final isError = service.connectionState == HermesConnectionState.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: isError
          ? AppTheme.error.withValues(alpha: 0.15)
          : AppTheme.accent.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.sync,
            color: isError ? AppTheme.error : AppTheme.accent,
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isError
                  ? (service.errorMessage ?? 'Connection error')
                  : service.connectionState.name,
              style: AppTheme.termFont.copyWith(
                color: isError ? AppTheme.error : AppTheme.accent,
                fontSize: 12,
              ),
            ),
          ),
          if (isError)
            TextButton(
              onPressed: service.reconnect,
              child: Text('Retry',
                  style: AppTheme.termFont.copyWith(
                      color: AppTheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageList(HermesService service) {
    if (service.messages.isEmpty) {
      return _buildEmptyState(service);
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: service.messages.length,
      itemBuilder: (_, i) => MessageBubble(message: service.messages[i]),
    );
  }

  Widget _buildEmptyState(HermesService service) {
    final connected = service.isConnected;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              connected ? Icons.chat_bubble_outline : Icons.link_off,
              color: AppTheme.textMuted,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              connected
                  ? 'Start a conversation\nwith Hermes'
                  : 'Not connected',
              textAlign: TextAlign.center,
              style: AppTheme.termFont.copyWith(
                  color: AppTheme.textMuted, fontSize: 15),
            ),
            if (!connected) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: service.reconnect,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('Reconnect',
                    style: AppTheme.termFont
                        .copyWith(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(HermesService service) {
    final canSend = service.isConnected && !service.isBusy;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: canSend ? AppTheme.border : AppTheme.border,
                    width: 1),
              ),
              child: TextField(
                controller: _inputCtrl,
                focusNode: _focusNode,
                enabled: canSend,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                style: AppTheme.termFont.copyWith(
                    color: AppTheme.textPrimary, fontSize: 15),
                cursorColor: AppTheme.accent,
                decoration: InputDecoration(
                  hintText: service.isBusy
                      ? 'Hermes is thinking...'
                      : 'Message Hermes...',
                  hintStyle: AppTheme.termFont.copyWith(
                      color: AppTheme.textMuted, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: canSend && _inputHasText
                    ? (_) => _send()
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            child: GestureDetector(
              onTap: (canSend && _inputHasText) ? _send : null,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (canSend && _inputHasText)
                      ? AppTheme.accent
                      : AppTheme.border,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_upward,
                  color: (canSend && _inputHasText)
                      ? Colors.black
                      : AppTheme.textMuted,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
