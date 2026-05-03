import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Shared PDF building blocks — colors, typography, common layouts.
///
/// All CourtSide reports use these helpers so the look stays consistent.
class PdfHelpers {
  PdfHelpers._();

  // ─── Brand colors (mirroring the app's primary orange) ──────────────────
  static const PdfColor primary = PdfColor.fromInt(0xFFE65100);
  static const PdfColor primarySoft = PdfColor.fromInt(0xFFFFE0B2);
  static const PdfColor textDark = PdfColor.fromInt(0xFF1F1F1F);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF6B6B6B);
  static const PdfColor divider = PdfColor.fromInt(0xFFE0E0E0);
  static const PdfColor success = PdfColor.fromInt(0xFF2E7D32);
  static const PdfColor danger = PdfColor.fromInt(0xFFC62828);

  // ─── Typography ─────────────────────────────────────────────────────────

  static pw.TextStyle titleStyle({double size = 24}) => pw.TextStyle(
        fontSize: size,
        fontWeight: pw.FontWeight.bold,
        color: textDark,
      );

  static pw.TextStyle subtitleStyle({double size = 12}) => pw.TextStyle(
        fontSize: size,
        color: textMuted,
      );

  static pw.TextStyle sectionHeaderStyle({double size = 14}) =>
      pw.TextStyle(
        fontSize: size,
        fontWeight: pw.FontWeight.bold,
        color: textDark,
      );

  static pw.TextStyle bodyStyle({double size = 11}) => pw.TextStyle(
        fontSize: size,
        color: textDark,
      );

  static pw.TextStyle mutedStyle({double size = 10}) => pw.TextStyle(
        fontSize: size,
        color: textMuted,
      );

  // ─── Layout helpers ─────────────────────────────────────────────────────

  /// Branded header at the top of every report.
  static pw.Widget header({
    required String title,
    required String subtitle,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: primary, width: 2),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 36,
            height: 36,
            decoration: const pw.BoxDecoration(
              color: primary,
              shape: pw.BoxShape.circle,
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'CS',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title, style: titleStyle(size: 18)),
                pw.SizedBox(height: 2),
                pw.Text(subtitle, style: mutedStyle()),
              ],
            ),
          ),
          pw.Text(
            'CourtSide',
            style: pw.TextStyle(
              fontSize: 10,
              color: textMuted,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Footer with a generated-on timestamp.
  static pw.Widget footer({required DateTime generatedAt}) {
    final ts =
        '${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}'
        '-${generatedAt.day.toString().padLeft(2, '0')}'
        ' ${generatedAt.hour.toString().padLeft(2, '0')}'
        ':${generatedAt.minute.toString().padLeft(2, '0')}';
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: divider)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated $ts',
            style: mutedStyle(),
          ),
          pw.Text(
            'CourtSide  ·  Basketball Stats Tracker',
            style: mutedStyle(),
          ),
        ],
      ),
    );
  }

  /// Section heading inside a report body.
  static pw.Widget sectionTitle(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
      child: pw.Text(text, style: sectionHeaderStyle()),
    );
  }

  /// A small key-value tile, useful for summary metrics.
  static pw.Widget statTile({
    required String label,
    required String value,
    PdfColor? valueColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: pw.BoxDecoration(
        color: primarySoft,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: valueColor ?? primary,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(label.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 8,
                color: textMuted,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.5,
              )),
        ],
      ),
    );
  }

  /// Builds a row of stat tiles, evenly spaced.
  static pw.Widget statTilesRow(List<({String label, String value})> tiles) {
    return pw.Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          pw.Expanded(
            child: statTile(label: tiles[i].label, value: tiles[i].value),
          ),
          if (i < tiles.length - 1) pw.SizedBox(width: 8),
        ],
      ],
    );
  }

  /// Standard page format we use everywhere — A4, sensible margins.
  static pw.PageTheme defaultPageTheme() {
    return const pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(32),
    );
  }

  /// Loads the bundled fonts. Default PDF fonts don't render Unicode
  /// (e.g., the · separator, em-dashes, etc.) reliably — calling this
  /// is harmless if the platform fonts work; we still try the fallback.
  /// For now we don't bundle a custom font; the default PDF font handles
  /// ASCII fine.
  static Future<void> ensureFontsLoaded() async {
    // Placeholder — if we ever bundle a custom font, load it here.
    // For now, no-op.
  }

  // ignore: unused_element
  static Future<pw.Font?> _tryLoadAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      return pw.Font.ttf(data);
    } catch (_) {
      return null;
    }
  }
}