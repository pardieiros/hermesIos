import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/chat_message.dart';
import '../theme.dart';
import 'tool_call_tile.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _thinkingExpanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.message;

    if (m.role == MessageRole.system) {
      return _buildSystemMessage(m);
    }

    if (m.isUser) {
      return _buildUserMessage(m);
    }

    return _buildAssistantMessage(m);
  }

  Widget _buildSystemMessage(ChatMessage m) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Text(
            m.text,
            style: AppTheme.termFont.copyWith(
                color: AppTheme.textMuted, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildUserMessage(ChatMessage m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Text(
                m.text,
                style: AppTheme.termFont.copyWith(
                    color: AppTheme.textPrimary, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantMessage(ChatMessage m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.35), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/hermes_logo.png',
              fit: BoxFit.cover,
              color: AppTheme.accent,
              colorBlendMode: BlendMode.modulate,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status line
                if (m.statusText != null && m.statusText!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppTheme.textMuted),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            m.statusText!,
                            style: AppTheme.termFont.copyWith(
                                color: AppTheme.textMuted, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Thinking block
                if (m.thinking != null && m.thinking!.isNotEmpty)
                  _buildThinkingBlock(m.thinking!),
                // Tool calls
                if (m.toolCalls.isNotEmpty)
                  ...m.toolCalls.map((t) => ToolCallTile(tool: t)),
                // Main text
                if (m.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border, width: 0.5),
                    ),
                    child: MarkdownBody(
                      data: m.text,
                      styleSheet: _markdownStyle(),
                      softLineBreak: true,
                    ),
                  ),
                // Streaming cursor
                if (m.isStreaming && m.text.isEmpty && m.toolCalls.isEmpty)
                  _buildCursor(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingBlock(String thinking) {
    return GestureDetector(
      onTap: () => setState(() => _thinkingExpanded = !_thinkingExpanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.thinkingColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: AppTheme.thinkingColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: AppTheme.thinkingColor, size: 14),
                const SizedBox(width: 6),
                Text('Thinking',
                    style: AppTheme.termFont.copyWith(
                        color: AppTheme.thinkingColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Icon(
                  _thinkingExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: AppTheme.thinkingColor,
                  size: 16,
                ),
              ],
            ),
            if (_thinkingExpanded) ...[
              const SizedBox(height: 8),
              Text(
                thinking,
                style: AppTheme.termFont.copyWith(
                    color: AppTheme.thinkingColor.withValues(alpha: 0.8),
                    fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCursor() {
    return Container(
      width: 8,
      height: 18,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: AppTheme.accent,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle() {
    return MarkdownStyleSheet(
      p: AppTheme.termFont.copyWith(
          color: AppTheme.textPrimary, fontSize: 14, height: 1.55),
      code: AppTheme.termFont.copyWith(
        color: AppTheme.accentGreen,
        fontSize: 13,
        backgroundColor: AppTheme.surfaceAlt,
      ),
      codeblockDecoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquoteDecoration: BoxDecoration(
        border: Border(
            left: BorderSide(color: AppTheme.accent, width: 3)),
      ),
      blockquotePadding:
          const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      blockquote: AppTheme.termFont.copyWith(
          color: AppTheme.textSecondary, fontSize: 14),
      h1: AppTheme.termFont.copyWith(
          color: AppTheme.accent,
          fontSize: 20,
          fontWeight: FontWeight.bold),
      h2: AppTheme.termFont.copyWith(
          color: AppTheme.accent,
          fontSize: 17,
          fontWeight: FontWeight.bold),
      h3: AppTheme.termFont.copyWith(
          color: AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.bold),
      strong: const TextStyle(
          fontFamily: 'Menlo', fontWeight: FontWeight.bold),
      em: const TextStyle(fontFamily: 'Menlo', fontStyle: FontStyle.italic),
      listBullet: AppTheme.termFont.copyWith(
          color: AppTheme.accent, fontSize: 14),
    );
  }
}
