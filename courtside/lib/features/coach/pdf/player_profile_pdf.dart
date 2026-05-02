import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/pdf_helpers.dart';
import '../../../models/game.dart';
import '../../../models/player.dart';
import '../../../models/team.dart';
import '../viewmodels/stats_notifiers.dart';

class PlayerProfilePdf {
  PlayerProfilePdf._();

  static Future<pw.Document> build({
    required Team team,
    required PlayerProfileData data,
  }) async {
    await PdfHelpers.ensureFontsLoaded();
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageTheme: PdfHelpers.defaultPageTheme(),
        header: (_) => PdfHelpers.header(
          title: 'Player Profile',
          subtitle:
              '#${data.player.jerseyNumber}  ${data.player.name}  ·  ${team.name}',
        ),
        footer: (_) =>
            PdfHelpers.footer(generatedAt: DateTime.now()),
        build: (_) => [
          pw.SizedBox(height: 16),
          _playerHeaderCard(data: data, team: team),
          pw.SizedBox(height: 12),
          _primaryStats(data),
          pw.SizedBox(height: 8),
          _shootingPercentages(data),
          PdfHelpers.sectionTitle('Game History'),
          _gameHistoryTable(data),
        ],
      ),
    );

    return doc;
  }

  // ─── Header card ────────────────────────────────────────────────────────

  static pw.Widget _playerHeaderCard({
    required PlayerProfileData data,
    required Team team,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfHelpers.primarySoft,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Big jersey badge
          pw.Container(
            width: 56,
            height: 56,
            decoration: pw.BoxDecoration(
              color: PdfHelpers.primary,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              '${data.player.jerseyNumber}',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  data.player.name,
                  style: PdfHelpers.titleStyle(size: 18),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  data.player.position.displayName,
                  style: PdfHelpers.bodyStyle(size: 11),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${team.name}  ·  ${team.season}',
                  style: PdfHelpers.mutedStyle(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Primary stats — total points + PPG ─────────────────────────────────

  static pw.Widget _primaryStats(PlayerProfileData data) {
    return PdfHelpers.statTilesRow([
      (label: 'Games Played', value: '${data.aggregate.gamesPlayed}'),
      (label: 'Total Points', value: '${data.aggregate.totalPoints}'),
      (
        label: 'Points / Game',
        value: data.aggregate.pointsPerGame.toStringAsFixed(1),
      ),
    ]);
  }

  // ─── Shooting percentages ───────────────────────────────────────────────

  static pw.Widget _shootingPercentages(PlayerProfileData data) {
    final agg = data.aggregate;
    final fgMade = agg.twoPtMade + agg.threePtMade;
    final fgAtt = fgMade + agg.twoPtMissed + agg.threePtMissed;
    final tpAtt = agg.threePtMade + agg.threePtMissed;
    final ftAtt = agg.ftMade + agg.ftMissed;

    return pw.Row(
      children: [
        pw.Expanded(
          child: _shootingTile(
            label: 'FG',
            pct: agg.fgPct,
            made: fgMade,
            attempted: fgAtt,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _shootingTile(
            label: '3PT',
            pct: agg.threePtPct,
            made: agg.threePtMade,
            attempted: tpAtt,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _shootingTile(
            label: 'FT',
            pct: agg.ftPct,
            made: agg.ftMade,
            attempted: ftAtt,
          ),
        ),
      ],
    );
  }

  static pw.Widget _shootingTile({
    required String label,
    required double? pct,
    required int made,
    required int attempted,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfHelpers.primarySoft,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: PdfHelpers.textMuted,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            pct == null ? '-' : '${pct.toStringAsFixed(1)}%',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfHelpers.textDark,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '$made / $attempted',
            style: PdfHelpers.mutedStyle(size: 9),
          ),
        ],
      ),
    );
  }

  // ─── Game history table ─────────────────────────────────────────────────

  static pw.Widget _gameHistoryTable(PlayerProfileData data) {
    if (data.perGamePoints.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        child: pw.Text(
          'No games played yet.',
          style: PdfHelpers.mutedStyle(),
        ),
      );
    }

    // Most recent first.
    final entries = [...data.perGamePoints]
      ..sort((a, b) => b.date.compareTo(a.date));

    final headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
      fontSize: 10,
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfHelpers.divider, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(70), // date
        1: pw.FlexColumnWidth(3),   // opponent
        2: pw.FixedColumnWidth(48), // result
        3: pw.FixedColumnWidth(40), // pts
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfHelpers.primary),
          children: [
            _headerCell('Date', headerStyle, alignLeft: true),
            _headerCell('Opponent', headerStyle, alignLeft: true),
            _headerCell('Result', headerStyle),
            _headerCell('PTS', headerStyle),
          ],
        ),
        for (final e in entries)
          pw.TableRow(
            children: [
              _bodyCell(_dateStr(e.date), alignLeft: true),
              _bodyCell(e.opponent, alignLeft: true),
              _resultCell(e.result),
              _bodyCell('${e.teamPoints}'),
            ],
          ),
      ],
    );
  }

  static pw.Widget _resultCell(GameResult? result) {
    PdfColor color;
    String label;
    switch (result) {
      case GameResult.win:
        color = PdfHelpers.success;
        label = 'W';
      case GameResult.loss:
        color = PdfHelpers.danger;
        label = 'L';
      case null:
        color = PdfHelpers.textMuted;
        label = '-';
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          color: color,
          fontWeight: pw.FontWeight.bold,
          fontSize: 11,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _headerCell(
    String text,
    pw.TextStyle style, {
    bool alignLeft = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Text(
        text,
        style: style,
        textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _bodyCell(String text, {bool alignLeft = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Text(
        text,
        style: PdfHelpers.bodyStyle(size: 10),
        textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
      ),
    );
  }

  static String _dateStr(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}