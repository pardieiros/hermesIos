import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../theme.dart';

class ToolCallTile extends StatefulWidget {
  final ToolCallEntry tool;

  const ToolCallTile({super.key, required this.tool});

  @override
  State<ToolCallTile> createState() => _ToolCallTileState();
}

class _ToolCallTileState extends State<ToolCallTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tool;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.toolBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.toolBorder),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _statusIcon(t),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.name,
                      style: AppTheme.termFont.copyWith(
                        color: AppTheme.accentGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (t.input.isNotEmpty) ...[
                    Text('input',
                        style: AppTheme.termFont.copyWith(
                            color: AppTheme.textMuted,
                            fontSize: 10,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t.input,
                        style: AppTheme.termFont.copyWith(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                  if (t.output != null && t.output!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('output',
                        style: AppTheme.termFont.copyWith(
                            color: AppTheme.textMuted,
                            fontSize: 10,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t.output!,
                        style: AppTheme.termFont.copyWith(
                            color: AppTheme.textSecondary, fontSize: 12),
                        maxLines: 20,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusIcon(ToolCallEntry t) {
    if (t.isRunning) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
            strokeWidth: 1.5, color: AppTheme.accentGreen),
      );
    }
    if (t.isComplete) {
      return const Icon(Icons.check_circle_outline,
          color: AppTheme.accentGreen, size: 14);
    }
    return const Icon(Icons.circle_outlined,
        color: AppTheme.textMuted, size: 14);
  }
}
