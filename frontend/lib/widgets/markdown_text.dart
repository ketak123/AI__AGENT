import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MarkdownText extends StatelessWidget {
  final String? text;
  final String? data;
  final TextStyle? baseStyle;

  const MarkdownText({
    super.key,
    this.text,
    this.data,
    this.baseStyle,
  });

  String get _rawText => text ?? data ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = _rawText.split('\n');
    final List<Widget> widgets = [];

    bool inCodeBlock = false;
    final List<String> codeLines = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Code block start/end
      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          // Close code block
          widgets.add(_buildCodeBlock(codeLines.join('\n'), context));
          codeLines.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        codeLines.add(line);
        continue;
      }

      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Headers
      if (trimmed.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              trimmed.substring(2),
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              trimmed.substring(3),
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFA5B4FC),
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(
              trimmed.substring(4),
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF38BDF8),
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('#### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(
              trimmed.substring(5),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF3F4F6),
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('> ')) {
        // Blockquote
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B).withValues(alpha: 0.5),
              border: const Border(
                left: BorderSide(color: Color(0xFF6366F1), width: 3),
              ),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Text(
              trimmed.substring(2),
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
                color: const Color(0xFFE0E7FF),
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('• ') ||
          trimmed.startsWith('- ') ||
          trimmed.startsWith('* ')) {
        // Bullet
        final content = trimmed.substring(2);
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  ' • ',
                  style: TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Expanded(child: _buildFormattedRichText(content, theme)),
              ],
            ),
          ),
        );
      } else if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        // Numbered list
        final match = RegExp(r'^(\d+\.)\s(.*)').firstMatch(trimmed);
        if (match != null) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${match.group(1)} ',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  Expanded(
                    child: _buildFormattedRichText(match.group(2) ?? '', theme),
                  ),
                ],
              ),
            ),
          );
        }
      } else if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        // Table row simplified
        if (!trimmed.contains('---')) {
          final cells = trimmed
              .split('|')
              .where((c) => c.isNotEmpty)
              .map((c) => c.trim())
              .toList();
          widgets.add(
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              decoration: BoxDecoration(
                color: widgets.length % 2 == 0
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: Row(
                children: cells
                    .map(
                      (cell) => Expanded(
                        child: _buildFormattedRichText(
                          cell,
                          theme,
                          fontSize: 12,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        }
      } else if (trimmed == '---') {
        widgets.add(
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 20),
        );
      } else {
        // Standard Paragraph
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: _buildFormattedRichText(trimmed, theme),
          ),
        );
      }
    }

    if (inCodeBlock && codeLines.isNotEmpty) {
      widgets.add(_buildCodeBlock(codeLines.join('\n'), context));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildCodeBlock(String code, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF030712),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: SelectableText(
        code,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 12.5,
          color: const Color(0xFF38BDF8),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildFormattedRichText(
    String text,
    ThemeData theme, {
    double fontSize = 13.5,
  }) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)');
    int currentIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: GoogleFonts.inter(
              fontSize: fontSize,
              color: const Color(0xFFE2E8F0),
              height: 1.45,
            ),
          ),
        );
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        spans.add(
          TextSpan(
            text: matchedText.substring(2, matchedText.length - 2),
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      } else if (matchedText.startsWith('*') && matchedText.endsWith('*')) {
        spans.add(
          TextSpan(
            text: matchedText.substring(1, matchedText.length - 1),
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontStyle: FontStyle.italic,
              color: const Color(0xFFCBD5E1),
            ),
          ),
        );
      } else if (matchedText.startsWith('`') && matchedText.endsWith('`')) {
        spans.add(
          TextSpan(
            text: ' ${matchedText.substring(1, matchedText.length - 1)} ',
            style: GoogleFonts.jetBrainsMono(
              fontSize: fontSize * 0.9,
              color: const Color(0xFFF472B6),
              backgroundColor: const Color(0xFF1E293B),
            ),
          ),
        );
      }

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: GoogleFonts.inter(
            fontSize: fontSize,
            color: const Color(0xFFE2E8F0),
            height: 1.45,
          ),
        ),
      );
    }

    return SelectableText.rich(TextSpan(children: spans));
  }
}
