/// Plain-Dart representation of a team, decoupled from the drift-generated
/// row class. Repositories return this; ViewModels and UI work with it.
class Team {
  final int id;
  final String name;
  final String season;
  final String homeCourt;
  final int coachId;
  final DateTime createdAt;

  const Team({
    required this.id,
    required this.name,
    required this.season,
    required this.homeCourt,
    required this.coachId,
    required this.createdAt,
  });

  Team copyWith({
    int? id,
    String? name,
    String? season,
    String? homeCourt,
    int? coachId,
    DateTime? createdAt,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      season: season ?? this.season,
      homeCourt: homeCourt ?? this.homeCourt,
      coachId: coachId ?? this.coachId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}