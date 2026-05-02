import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/database/app_database.dart';
import '../../../core/utils/pdf_helpers.dart';
import '../../../core/utils/stats_calculator.dart';
import '../../../models/game.dart';
import '../../../models/player.dart';
import '../../../models/team.dart';

class GameSummaryPdf {
  GameSummaryPdf._();

  static Future<pw.Document> build({
    required Team team,
    required Game game,
    required List<Player> players,
    required Map<int, GameStatRow> statsByPlayerId,
  }) async {
    await PdfHelpers.ensureFontsLoaded();
    final doc = pw.Document();

    final teamScore =
        StatsCalculator.teamScoreFromStats(statsByPlayerId.values);
    final dateStr = '${game.date.year}-'
        '${game.date.month.toString().padLeft(2, '0')}-'
        '${game.date.day.toString().padLeft(2, '0')}';

    // Players sorted by points desc — top scorers first.
    final sorted = [...players]..sort((a, b) {
        final aPts = StatsCalculator.totalPoints(
            statsByPlayerId[a.id] ?? _emptyRow());
        final bPts = StatsCalculator.totalPoints(
            statsByPlayerId[b.id] ?? _emptyRow());
        return bPts.compareTo(aPts);
      });

    doc.addPage(
      pw.MultiPage(
        pageTheme: PdfHelpers.defaultPageTheme(),
        header: (_) => PdfHelpers.header(
          title: 'Game Summary',
          subtitle: '${team.name}  vs  ${game.opponent}',
        ),
        footer: (_) =>
            PdfHelpers.footer(generatedAt: DateTime.now()),
        build: (_) => [
          pw.SizedBox(height: 16),
          _resultBanner(game: game, teamScore: teamScore),
          pw.SizedBox(height: 16),
          _gameMetaRow(game: game, dateStr: dateStr),
          PdfHelpers.sectionTitle('Player Stats'),
          _playerStatsTable(
            players: sorted,
            statsByPlayerId: statsByPlayerId,
          ),
        ],
      ),
    );

    return doc;
  }

  // ─── Building blocks ────────────────────────────────────────────────────

  static pw.Widget _resultBanner({
    required Game game,
    required int teamScore,
  }) {
    final (label, color) = _resultStyle(game);

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                '$teamScore',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 36,
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Text(
                '-',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 30,
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Text(
                '${game.opponentScore}',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 36,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'vs ${game.opponent}',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  static (String, PdfColor) _resultStyle(Game g) {
    if (!g.isFinished) {
      return ('IN PROGRESS', PdfHelpers.textMuted);
    }
    switch (g.result) {
      case GameResult.win:
        return ('WIN', PdfHelpers.success);
      case GameResult.loss:
        return ('LOSS', PdfHelpers.danger);
      case null:
        return ('FINAL', PdfHelpers.textMuted);
    }
  }

  static pw.Widget _gameMetaRow({
    required Game game,
    required String dateStr,
  }) {
    return pw.Row(
      children: [
        _metaPill(label: 'Date', value: dateStr),
        pw.SizedBox(width: 8),
        _metaPill(label: 'Location', value: game.homeAway.displayName),
      ],
    );
  }

  static pw.Widget _metaPill({
    required String label,
    required String value,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfHelpers.primarySoft,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                color: PdfHelpers.textMuted,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              )),
          pw.SizedBox(width: 6),
          pw.Text(value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfHelpers.textDark,
              )),
        ],
      ),
    );
  }

  static pw.Widget _playerStatsTable({
    required List<Player> players,
    required Map<int, GameStatRow> statsByPlayerId,
  }) {
    final headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
      fontSize: 10,
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfHelpers.divider, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(28), // jersey
        1: pw.FlexColumnWidth(3),   // name
        2: pw.FixedColumnWidth(40), // PTS
        3: pw.FixedColumnWidth(48), // FG%
        4: pw.FixedColumnWidth(48), // 3P%
        5: pw.FixedColumnWidth(48), // FT%
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfHelpers.primary),
          children: [
            _headerCell('#', headerStyle, alignLeft: true),
            _headerCell('Player', headerStyle, alignLeft: true),
            _headerCell('PTS', headerStyle),
            _headerCell('FG%', headerStyle),
            _headerCell('3P%', headerStyle),
            _headerCell('FT%', headerStyle),
          ],
        ),
        for (final p in players)
          pw.TableRow(
            children: _playerStatsRowCells(p, statsByPlayerId[p.id]),
          ),
      ],
    );
  }

  static List<pw.Widget> _playerStatsRowCells(
    Player player,
    GameStatRow? stat,
  ) {
    final s = stat ?? _emptyRow();
    final pts = StatsCalculator.totalPoints(s);
    final fg = StatsCalculator.fieldGoalPct(s);
    final tp = StatsCalculator.threePtPct(s);
    final ft = StatsCalculator.freeThrowPct(s);

    return [
      _bodyCell('${player.jerseyNumber}', alignLeft: true),
      _bodyCell(player.name, alignLeft: true),
      _bodyCell('$pts'),
      _bodyCell(_pct(fg)),
      _bodyCell(_pct(tp)),
      _bodyCell(_pct(ft)),
    ];
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

  static String _pct(double? v) {
    if (v == null) return '-';
    return '${v.toStringAsFixed(1)}%';
  }

  /// A blank stat row used as a fallback so we never null-crash when
  /// rendering. Used for players who somehow have no stat row.
  static GameStatRow _emptyRow() {
    return const GameStatRow(
      id: 0,
      gameId: 0,
      playerId: 0,
      twoPtMade: 0,
      twoPtMissed: 0,
      threePtMade: 0,
      threePtMissed: 0,
      ftMade: 0,
      ftMissed: 0,
    );
  }
}