/// The five basketball positions. Stored in PLAYERS.position as a short
/// string code. Keeping them as an enum lets the UI show proper names
/// ("Point Guard") while the DB stays compact ("PG").
enum PlayerPosition {
  pointGuard,
  shootingGuard,
  smallForward,
  powerForward,
  center,
}

extension PlayerPositionX on PlayerPosition {
  /// The two-letter code stored in the DB.
  String get code {
    switch (this) {
      case PlayerPosition.pointGuard:
        return 'PG';
      case PlayerPosition.shootingGuard:
        return 'SG';
      case PlayerPosition.smallForward:
        return 'SF';
      case PlayerPosition.powerForward:
        return 'PF';
      case PlayerPosition.center:
        return 'C';
    }
  }

  /// Full position name for UI display.
  String get displayName {
    switch (this) {
      case PlayerPosition.pointGuard:
        return 'Point Guard';
      case PlayerPosition.shootingGuard:
        return 'Shooting Guard';
      case PlayerPosition.smallForward:
        return 'Small Forward';
      case PlayerPosition.powerForward:
        return 'Power Forward';
      case PlayerPosition.center:
        return 'Center';
    }
  }

  static PlayerPosition fromCode(String code) {
    switch (code) {
      case 'PG':
        return PlayerPosition.pointGuard;
      case 'SG':
        return PlayerPosition.shootingGuard;
      case 'SF':
        return PlayerPosition.smallForward;
      case 'PF':
        return PlayerPosition.powerForward;
      case 'C':
        return PlayerPosition.center;
      default:
        throw ArgumentError('Unknown position code: $code');
    }
  }
}

/// Plain-Dart representation of a player.
class Player {
  final int id;
  final String name;
  final int jerseyNumber;
  final PlayerPosition position;
  final int teamId;

  const Player({
    required this.id,
    required this.name,
    required this.jerseyNumber,
    required this.position,
    required this.teamId,
  });

  Player copyWith({
    int? id,
    String? name,
    int? jerseyNumber,
    PlayerPosition? position,
    int? teamId,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      position: position ?? this.position,
      teamId: teamId ?? this.teamId,
    );
  }
}