import 'guess_result.dart';

/// Distinguishes between an evaluated perfume guess and an intentional turn skip.
enum TurnType {
  guess,
  skip,
}

/// Represents an individual turn in a 6-turn Scentle session.
class TurnEntry {
  final TurnType type;
  final int turnNumber; // 1-indexed (1 to 6)
  final GuessResult? guessResult;

  const TurnEntry.guess({
    required this.turnNumber,
    required GuessResult result,
  })  : type = TurnType.guess,
        guessResult = result;

  const TurnEntry.skipped({
    required this.turnNumber,
  })  : type = TurnType.skip,
        guessResult = null;

  bool get isGuess => type == TurnType.guess;
  bool get isSkip => type == TurnType.skip;

  /// Serializes turn entry for local persistence.
  Map<String, dynamic> toJson() {
    if (isGuess && guessResult != null) {
      return {
        'type': 'guess',
        'turnNumber': turnNumber,
        'perfumeId': guessResult!.guessedPerfume.id,
      };
    }
    return {
      'type': 'skip',
      'turnNumber': turnNumber,
    };
  }
}
