import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared visual building blocks that mirror the layout language of the
/// DayOne_Review2_Demo browser prototype (`.panel`, `.chip`, `.metric`,
/// the uppercase letter-spaced "eyebrow" labels) — reused across the real
/// app's screens so the Flutter UI reads as the same product as the demo.

/// A bordered, cream/white panel with an optional header: title, subtitle
/// and a trailing widget (a chip, a button). Mirrors the demo's `.panel`
/// + `.panel-head`.
class AppPanel extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppPanel({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// A small rounded label — mirrors the demo's `.chip`.
class AppChip extends StatelessWidget {
  final String text;
  final Color? color;
  const AppChip(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}

/// Uppercase, letter-spaced micro-label used above a section — mirrors
/// the demo's teal "SIMULATED SENSOR LAYER"-style eyebrow text.
class EyebrowLabel extends StatelessWidget {
  final String text;
  const EyebrowLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.accent,
        fontWeight: FontWeight.w800,
        fontSize: 11,
        letterSpacing: 1.6,
      ),
    );
  }
}

/// A single stat tile — mirrors the demo dashboard's `.metric` cards
/// (tab brightness / audio level / room devices / local profile).
class MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String note;

  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.inkSoft),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            style: const TextStyle(fontSize: 10, color: AppColors.inkSoft),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A small pill with a status dot — mirrors the demo header's green
/// "● Offline-first" badge.
class StatusDotChip extends StatelessWidget {
  final String text;
  const StatusDotChip(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent)),
        ],
      ),
    );
  }
}

/// A faint-bordered box for a caveat/disclaimer line — mirrors the demo's
/// dashed-outline note boxes under each control panel. (Plain border, not
/// literally dashed — no extra package pulled in just for a hairline.)
class NoteBox extends StatelessWidget {
  final String text;
  const NoteBox(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.inkSoft, fontSize: 11.5, height: 1.4)),
    );
  }
}

/// The "COGNITION 2026 · REVIEW 2 DEMO" header block repeated at the top
/// of the demo's own pages: an eyebrow row with status badges on the
/// right (wrapping below on narrow windows), then a large heading below.
/// Kept app-state-free on purpose (just callbacks) so this stays a pure
/// visual building block like the rest of this file.
class DemoHeaderBar extends StatelessWidget {
  final String heading;
  final String profileLabel;
  final VoidCallback? onReset;

  const DemoHeaderBar({
    super.key,
    required this.heading,
    this.profileLabel = 'Local profile',
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 560;
        final badges = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const StatusDotChip('Offline-first'),
            AppChip(profileLabel),
            OutlinedButton(
              onPressed: onReset,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Reset demo', style: TextStyle(fontSize: 12)),
            ),
          ],
        );
        final eyebrow = const EyebrowLabel('Cognition 2026 · Review 2 demo');
        final headingText = Text(
          heading,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.6,
          ),
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [eyebrow, const SizedBox(height: 10), badges, const SizedBox(height: 14), headingText],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [Expanded(child: eyebrow), badges],
            ),
            const SizedBox(height: 14),
            headingText,
          ],
        );
      },
    );
  }
}
