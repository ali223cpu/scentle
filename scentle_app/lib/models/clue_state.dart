import '../core/utils/string_normalizer.dart';
import 'perfume_model.dart';

/// Computed progressive clue unlocks based on turns taken and game status.
class ClueState {
  final PerfumeModel target;
  final int mistakesCount; // Number of failed guesses + turn skips
  final bool isGameOver;
  final Set<String> discoveredNotesLower;
  final List<String> bonusRevealedNotes;

  const ClueState({
    required this.target,
    required this.mistakesCount,
    required this.isGameOver,
    this.discoveredNotesLower = const {},
    this.bonusRevealedNotes = const [],
  });

  static const int maxTurns = 6;

  int get currentTurnNumber => (mistakesCount + 1).clamp(1, maxTurns);

  // Turn 1 (Always unlocked from game start: mistakesCount >= 0)
  List<String> get mainAccords => target.accords.take(5).toList();
  String get gender => target.gender;

  // Turn 2 (mistakesCount >= 1 or isGameOver)
  bool get isTopNotesUnlocked => mistakesCount >= 1 || isGameOver;
  List<String> get topNotes =>
      isTopNotesUnlocked ? target.notes.topDisplay : const [];
  String? get releaseDecade =>
      (mistakesCount >= 1 || isGameOver) ? target.releaseDecade : null;

  // Turn 3 (mistakesCount >= 2 or isGameOver)
  bool get isMiddleNotesUnlocked => mistakesCount >= 2 || isGameOver;
  List<String> get middleNotes =>
      isMiddleNotesUnlocked ? target.notes.middleDisplay : const [];
  String? get country =>
      (mistakesCount >= 2 || isGameOver) ? target.country : null;

  // Turn 4 (mistakesCount >= 3 or isGameOver)
  bool get isBaseNotesUnlocked => mistakesCount >= 3 || isGameOver;
  List<String> get baseNotes =>
      isBaseNotesUnlocked ? target.notes.baseDisplay : const [];
  String? get perfumer =>
      (mistakesCount >= 3 || isGameOver) ? target.perfumer : null;

  // Turn 5 (mistakesCount >= 4 or isGameOver)
  String? get brand =>
      (mistakesCount >= 4 || isGameOver) ? target.brand : null;
  int? get exactYear =>
      (mistakesCount >= 4 || isGameOver) ? target.year : null;

  // Turn 6 (mistakesCount >= 5 or isGameOver)
  bool get showBottleImage => mistakesCount >= 5 || isGameOver;
  double get blurSigma => isGameOver ? 0.0 : (showBottleImage ? 18.0 : 0.0);

  // Solved / Game Over
  String? get fullPerfumeName => isGameOver ? target.name : null;

  /// Checks if a given note was identified by the player across their prior guesses.
  bool isNoteMatchedByPlayer(String displayNote) {
    final key = StringNormalizer.normalizeNoteKey(displayNote);
    return discoveredNotesLower.contains(key) ||
        bonusRevealedNotes
            .map(StringNormalizer.normalizeNoteKey)
            .contains(key);
  }
}
