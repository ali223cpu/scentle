import '../models/guess_result.dart';
import '../models/perfume_model.dart';
import '../models/turn_entry.dart';

/// Pure, stateless service executing game evaluation logic.
class GameEngineService {
  const GameEngineService();

  /// Compares a player guess against the target and produces a complete GuessResult.
  GuessResult evaluateGuess(PerfumeModel guess, PerfumeModel target) {
    return GuessResult.evaluate(guess: guess, target: target);
  }

  /// Creates an evaluated TurnEntry for a perfume guess.
  TurnEntry createGuessEntry({
    required int turnNumber,
    required PerfumeModel guess,
    required PerfumeModel target,
  }) {
    final result = evaluateGuess(guess, target);
    return TurnEntry.guess(turnNumber: turnNumber, result: result);
  }

  /// Creates a TurnEntry representing an intentional skip.
  TurnEntry createSkipEntry(int turnNumber) {
    return TurnEntry.skipped(turnNumber: turnNumber);
  }
}
