import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../models/connection_settings.dart';
import '../services/hermes_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import 'chat_screen.dart';

class ConnectScreen extends StatefulWidget {
  final ConnectionSettings? savedSettings;

  const ConnectScreen({super.key, this.savedSettings});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '8765');
  final _tokenCtrl = TextEditingController();
  bool _useHttps = false;
  bool _isConnecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.savedSettings;
    if (s != null) {
      _hostCtrl.text = s.host;
      _portCtrl.text = s.port.toString();
      _tokenCtrl.text = s.token;
      _useHttps = s.useHttps;
    }
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = _hostCtrl.text.trim();
    final portStr = _portCtrl.text.trim();
    final token = _tokenCtrl.text.trim();

    if (host.isEmpty || token.isEmpty) {
      setState(() => _error = 'Host and token are required');
      return;
    }

    final port = int.tryParse(portStr);
    if (port == null || port < 1 || port > 65535) {
      setState(() => _error = 'Invalid port number');
      return;
    }

    final settings = ConnectionSettings(
      host: host,
      port: port,
      token: token,
      useHttps: _useHttps,
    );

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    await SettingsService().save(settings);

    if (!mounted) return;
    final service = context.read<HermesService>();
    await service.connect(settings);

    if (!mounted) return;

    if (service.connectionState == HermesConnectionState.connected ||
        service.connectionState == HermesConnectionState.connecting) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    } else {
      setState(() {
        _isConnecting = false;
        _error = service.errorMessage ?? 'Connection failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Logo / title
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.psychology,
                        color: Colors.black, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hermes',
                          style: AppTheme.termFont.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accent)),
                      Text('Agent Terminal',
                          style: AppTheme.termFont.copyWith(
                              fontSize: 13, color: AppTheme.textMuted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Text('Connect to Server',
                  style: AppTheme.termFont.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 24),
              _buildField('Host', _hostCtrl,
                  hint: '192.168.1.x or your-server.com',
                  keyboardType: TextInputType.url),
              const SizedBox(height: 16),
              _buildField('Port', _portCtrl,
                  hint: '8765',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildField('Session Token', _tokenCtrl,
                  hint: 'Paste your Hermes session token',
                  obscure: true),
              const SizedBox(height: 16),
              Row(
                children: [
                  CupertinoSwitch(
                    value: _useHttps,
                    activeTrackColor: AppTheme.accent,
                    onChanged: (v) => setState(() => _useHttps = v),
                  ),
                  const SizedBox(width: 12),
                  Text('Use WSS / HTTPS',
                      style: AppTheme.termFont.copyWith(
                          color: AppTheme.textSecondary)),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: AppTheme.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: AppTheme.termFont.copyWith(
                                color: AppTheme.error, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isConnecting ? null : _connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isConnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : Text('Connect',
                          style: AppTheme.termFont.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black)),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Start Hermes with: hermes --tui',
                  style: AppTheme.termFont.copyWith(
                      color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTheme.termFont.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 12,
                letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          autocorrect: false,
          style: AppTheme.termFont.copyWith(color: AppTheme.textPrimary),
          cursorColor: AppTheme.accent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                AppTheme.termFont.copyWith(color: AppTheme.textMuted, fontSize: 14),
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
