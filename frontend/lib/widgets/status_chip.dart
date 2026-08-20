import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final bool compact;

  const StatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;
    IconData icon;
    String label = status.replaceAll('_', ' ').toUpperCase();

    switch (status.toLowerCase()) {
      case 'done':
      case 'completed':
      case 'active':
        bg = const Color(0xFF065F46).withValues(alpha: 0.3);
        fg = const Color(0xFF34D399);
        border = const Color(0xFF059669);
        icon = Icons.check_circle_outline;
        break;
      case 'running':
      case 'orchestrating':
      case 'executing':
        bg = const Color(0xFF1E3A8A).withValues(alpha: 0.35);
        fg = const Color(0xFF60A5FA);
        border = const Color(0xFF2563EB);
        icon = Icons.sync;
        break;
      case 'failed':
      case 'error':
        bg = const Color(0xFF7F1D1D).withValues(alpha: 0.35);
        fg = const Color(0xFFF87171);
        border = const Color(0xFFDC2626);
        icon = Icons.error_outline;
        break;
      case 'plan_generated':
        bg = const Color(0xFF4C1D95).withValues(alpha: 0.35);
        fg = const Color(0xFFA78BFA);
        border = const Color(0xFF7C3AED);
        icon = Icons.auto_awesome;
        break;
      default:
        bg = const Color(0xFF374151).withValues(alpha: 0.35);
        fg = const Color(0xFF9CA3AF);
        border = const Color(0xFF4B5563);
        icon = Icons.schedule;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
