import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/pdf_helpers.dart';
import '../../../models/game.dart';
import '../../../models/team.dart';
import '../viewmodels/stats_notifiers.dart';

class SeasonAnalyticsPdf {
  SeasonAnalyticsPdf._();

  static Future<pw.Document> build({
    required Team team,
    required SeasonAnalytics analytics,
  }) async {
    await PdfHelpers.ensureFontsLoaded();
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageTheme: PdfHelpers.defaultPageTheme(),
        header: (_) => PdfHelpers.header(
          title: 'Season Analytics',
          subtitle: '${team.name}  ·  ${team.season}',
        ),
        footer: (_) =>
            PdfHelpers.footer(generatedAt: DateTime.now()),
        build: (_) => [
          pw.SizedBox(height: 16),
          _topStats(analytics),
          pw.SizedBox(height: 8),
          _secondaryStats(analytics),
          PdfHelpers.sectionTitle('Points per Game'),
          _pointsTable(analytics),
          PdfHelpers.sectionTitle('Player Leaderboard'),
          _leaderboardTable(analytics),
        ],
      ),
    );

    return doc;
  }

  // ─── Top row: Wins / Losses / Win% ──────────────────────────────────────

  static pw.Widget _topStats(SeasonAnalytics a) {
    return PdfHelpers.statTilesRow([
      (label: 'Wins', value: '${a.wins}'),
      (label: 'Losses', value: '${a.losses}'),
      (label: 'Win %', value: '${a.winPct.toStringAsFixed(0)}%'),
    ]);
  }

  static pw.Widget _secondaryStats(SeasonAnalytics a) {
    return PdfHelpers.statTilesRow([
      (label: 'Games', value: '${a.gamesPlayed}'),
      (label: 'Avg PTS', value: a.avgPointsPerGame.toStringAsFixed(1)),
      (
        label: 'Team FG',
        value: a.teamFgPct == null
            ? '-'
            : '${a.teamFgPct!.toStringAsFixed(1)}%',
      ),
    ]);
  }

  // ─── Points per game table (instead of chart, since text translates
  //     better to print than a chart image) ─────────────────────────────────

  static pw.Widget _pointsTable(SeasonAnalytics a) {
    if (a.pointsByGame.isEmpty) {
      return _emptyNote('No games played yet.');
    }

    final headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
      fontSize: 10,
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfHelpers.divider, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(70),
        1: pw.FlexColumnWidth(3),
        2: pw.FixedColumnWidth(48),
        3: pw.FixedColumnWidth(48),
        4: pw.FixedColumnWidth(40),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfHelpers.primary),
          children: [
            _headerCell('Date', headerStyle, alignLeft: true),
            _headerCell('Opponent', headerStyle, alignLeft: true),
            _headerCell('PTS', headerStyle),
            _headerCell('Opp', headerStyle),
            _headerCell('Result', headerStyle),
          ],
        ),
        for (final e in a.pointsByGame)
          pw.TableRow(
            children: [
              _bodyCell(_dateStr(e.date), alignLeft: true),
              _bodyCell(e.opponent, alignLeft: true),
              _bodyCell('${e.teamPoints}'),
              _bodyCell('${e.opponentPoints}'),
              _resultCell(e.result),
            ],
          ),
      ],
    );
  }

  // ─── Leaderboard table ──────────────────────────────────────────────────

  static pw.Widget _leaderboardTable(SeasonAnalytics a) {
    if (a.leaderboard.isEmpty) {
      return _emptyNote('No players on the roster.');
    }

    final headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
      fontSize: 10,
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfHelpers.divider, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(28), // rank
        1: pw.FixedColumnWidth(28), // jersey
        2: pw.FlexColumnWidth(3),   // name
        3: pw.FixedColumnWidth(40), // GP
        4: pw.FixedColumnWidth(40), // PTS
        5: pw.FixedColumnWidth(48), // PPG
        6: pw.FixedColumnWidth(48), // FG%
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfHelpers.primary),
          children: [
            _headerCell('#', headerStyle),
            _headerCell('No.', headerStyle),
            _headerCell('Player', headerStyle, alignLeft: true),
            _headerCell('GP', headerStyle),
            _headerCell('PTS', headerStyle),
            _headerCell('PPG', headerStyle),
            _headerCell('FG%', headerStyle),
          ],
        ),
        for (var i = 0; i < a.leaderboard.length; i++)
          pw.TableRow(
            children: [
              _bodyCell('${i + 1}'),
              _bodyCell('${a.leaderboard[i].player.jerseyNumber}'),
              _bodyCell(a.leaderboard[i].player.name, alignLeft: true),
              _bodyCell('${a.leaderboard[i].aggregate.gamesPlayed}'),
              _bodyCell('${a.leaderboard[i].aggregate.totalPoints}'),
              _bodyCell(
                a.leaderboard[i].aggregate.pointsPerGame.toStringAsFixed(1),
              ),
              _bodyCell(_pct(a.leaderboard[i].aggregate.fgPct)),
            ],
          ),
      ],
    );
  }

  // ─── Cell helpers (same shape as game summary) ──────────────────────────

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

  static String _dateStr(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _pct(double? v) {
    if (v == null) return '-';
    return '${v.toStringAsFixed(1)}%';
  }

  static pw.Widget _emptyNote(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      child: pw.Text(text, style: PdfHelpers.mutedStyle()),
    );
  }
}