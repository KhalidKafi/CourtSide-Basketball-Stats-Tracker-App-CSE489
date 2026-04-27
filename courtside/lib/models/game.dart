/// Whether the game was played at home or away.
enum HomeAway { home, away }

extension HomeAwayX on HomeAway {
  String get code {
    switch (this) {
      case HomeAway.home:
        return 'home';
      case HomeAway.away:
        return 'away';
    }
  }

  String get displayName {
    switch (this) {
      case HomeAway.home:
        return 'Home';
      case HomeAway.away:
        return 'Away';
    }
  }

  static HomeAway fromCode(String code) {
    switch (code) {
      case 'home':
        return HomeAway.home;
      case 'away':
        return HomeAway.away;
      default:
        throw ArgumentError('Unknown home/away code: $code');
    }
  }
}

/// The final result of a game. Null means the game hasn't been finalized.
/// No "draw" — basketball overtime always resolves a tie.
enum GameResult { win, loss }

extension GameResultX on GameResult {
  String get code {
    switch (this) {
      case GameResult.win:
        return 'win';
      case GameResult.loss:
        return 'loss';
    }
  }

  String get displayName {
    switch (this) {
      case GameResult.win:
        return 'Win';
      case GameResult.loss:
        return 'Loss';
    }
  }

  static GameResult fromCode(String code) {
    switch (code) {
      case 'win':
        return GameResult.win;
      case 'loss':
        return GameResult.loss;
      default:
        throw ArgumentError('Unknown game result code: $code');
    }
  }
}

/// Plain-Dart Game model. The `date` field is stored as a DateTime,
/// even though the DB column is an ISO string — the repository handles
/// the conversion.
class Game {
  final int id;
  final String opponent;
  final DateTime date;
  final HomeAway homeAway;
  final GameResult? result;
  final int opponentScore;
  final int teamId;
  final bool isFinished;
  final DateTime createdAt;

  const Game({
    required this.id,
    required this.opponent,
    required this.date,
    required this.homeAway,
    required this.result,
    required this.opponentScore,
    required this.teamId,
    required this.isFinished,
    required this.createdAt,
  });

  Game copyWith({
    int? id,
    String? opponent,
    DateTime? date,
    HomeAway? homeAway,
    GameResult? result,
    int? opponentScore,
    int? teamId,
    bool? isFinished,
    DateTime? createdAt,
  }) {
    return Game(
      id: id ?? this.id,
      opponent: opponent ?? this.opponent,
      date: date ?? this.date,
      homeAway: homeAway ?? this.homeAway,
      result: result ?? this.result,
      opponentScore: opponentScore ?? this.opponentScore,
      teamId: teamId ?? this.teamId,
      isFinished: isFinished ?? this.isFinished,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}