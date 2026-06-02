import 'package:flutter/material.dart';

import '../services/hermes_service.dart';
import '../theme.dart';

class ApprovalSheet extends StatefulWidget {
  final ApprovalRequest request;
  final void Function(bool approved, String? text) onRespond;

  const ApprovalSheet({
    super.key,
    required this.request,
    required this.onRespond,
  });

  @override
  State<ApprovalSheet> createState() => _ApprovalSheetState();
}

class _ApprovalSheetState extends State<ApprovalSheet> {
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  String get _typeLabel {
    switch (widget.request.type) {
      case 'approval':
        return 'Approval Required';
      case 'sudo':
        return 'Elevated Permission';
      case 'secret':
        return 'Secret Required';
      case 'clarify':
        return 'Clarification';
      default:
        return 'Input Required';
    }
  }

  IconData get _typeIcon {
    switch (widget.request.type) {
      case 'sudo':
        return Icons.security;
      case 'secret':
        return Icons.key;
      case 'clarify':
        return Icons.help_outline;
      default:
        return Icons.check_circle_outline;
    }
  }

  bool get _needsText =>
      widget.request.type == 'clarify' || widget.request.type == 'secret';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(_typeIcon, color: AppTheme.accent, size: 20),
              const SizedBox(width: 10),
              Text(
                _typeLabel,
                style: AppTheme.termFont.copyWith(
                  color: AppTheme.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              widget.request.message,
              style: AppTheme.termFont.copyWith(
                  color: AppTheme.textPrimary, fontSize: 14),
            ),
          ),
          if (_needsText) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _textCtrl,
              autofocus: true,
              obscureText: widget.request.type == 'secret',
              style: AppTheme.termFont.copyWith(color: AppTheme.textPrimary),
              cursorColor: AppTheme.accent,
              decoration: InputDecoration(
                hintText: widget.request.type == 'secret'
                    ? 'Enter value'
                    : 'Your response...',
                hintStyle: AppTheme.termFont
                    .copyWith(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.bg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  borderSide:
                      const BorderSide(color: AppTheme.accent, width: 1.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              if (!_needsText) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => widget.onRespond(false, null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Deny',
                        style: AppTheme.termFont.copyWith(
                            color: AppTheme.error,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final text =
                        _textCtrl.text.trim().isEmpty ? null : _textCtrl.text.trim();
                    widget.onRespond(true, text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    _needsText ? 'Submit' : 'Approve',
                    style: AppTheme.termFont.copyWith(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
