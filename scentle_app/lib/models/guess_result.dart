import '../core/utils/string_normalizer.dart';
import 'perfume_model.dart';

/// Evaluation status for individual fragrance attributes.
enum MatchStatus {
  exact,
  close,
  miss,
}

/// Directional guidance for release year.
enum YearDirection {
  equal,
  newer, // Target is newer than guess (UI displays ↑ arrow)
  older, // Target is older than guess (UI displays ↓ arrow)
}

/// Comprehensive, immutable result of comparing a guessed perfume against the secret target.
class GuessResult {
  final PerfumeModel guessedPerfume;
  final bool isCorrect;
  final bool isFlankerMatch;
  final MatchStatus brandStatus;
  final MatchStatus yearStatus;
  final YearDirection yearDirection;
  final MatchStatus genderStatus;
  final MatchStatus perfumerStatus;
  final List<String> sharedNotes;
  final MatchStatus notesStatus;
  final List<String> sharedAccords;
  final bool topAccordExactMatch;
  final MatchStatus accordsStatus;

  const GuessResult({
    required this.guessedPerfume,
    required this.isCorrect,
    required this.isFlankerMatch,
    required this.brandStatus,
    required this.yearStatus,
    required this.yearDirection,
    required this.genderStatus,
    required this.perfumerStatus,
    required this.sharedNotes,
    required this.notesStatus,
    required this.sharedAccords,
    required this.topAccordExactMatch,
    required this.accordsStatus,
  });

  /// Evaluates a guessed perfume against the secret target with fragrance-specific rules.
  factory GuessResult.evaluate({
    required PerfumeModel guess,
    required PerfumeModel target,
  }) {
    final isCorrect = guess.id == target.id;

    // Brand Comparison
    final isBrandMatch = guess.normalizedBrand == target.normalizedBrand;
    final MatchStatus brandStatus;
    if (isBrandMatch) {
      brandStatus = MatchStatus.exact;
    } else if (guess.country != 'Unknown' &&
        target.country != 'Unknown' &&
        guess.country.trim().isNotEmpty &&
        target.country.trim().isNotEmpty &&
        guess.country.toLowerCase() == target.country.toLowerCase()) {
      brandStatus = MatchStatus.close;
    } else {
      brandStatus = MatchStatus.miss;
    }

    // Flanker detection: same brand, and shared flankerLineId or overlapping base title
    final bool isFlankerMatch;
    if (!isCorrect && isBrandMatch) {
      final sharedLineId = guess.flankerLineId.isNotEmpty &&
          guess.flankerLineId == target.flankerLineId;
      final nameOverlap =
          guess.normalizedName.contains(target.normalizedName) ||
              target.normalizedName.contains(guess.normalizedName);
      isFlankerMatch = sharedLineId || nameOverlap;
    } else {
      isFlankerMatch = false;
    }

    // Release Year Comparison & Direction
    final MatchStatus yearStatus;
    final YearDirection yearDirection;
    if (guess.year > 0 && target.year > 0) {
      final diff = guess.year - target.year;
      if (diff == 0) {
        yearStatus = MatchStatus.exact;
        yearDirection = YearDirection.equal;
      } else {
        yearStatus = (diff.abs() <= 5) ? MatchStatus.close : MatchStatus.miss;
        yearDirection =
            (target.year > guess.year) ? YearDirection.newer : YearDirection.older;
      }
    } else {
      yearStatus = MatchStatus.miss;
      yearDirection = YearDirection.equal;
    }

    // Gender Comparison
    final gGuess = guess.gender.toLowerCase().trim();
    final gTarget = target.gender.toLowerCase().trim();
    final MatchStatus genderStatus;
    if (gGuess == gTarget) {
      genderStatus = MatchStatus.exact;
    } else if (gGuess == 'unisex' || gTarget == 'unisex') {
      genderStatus = MatchStatus.close;
    } else {
      genderStatus = MatchStatus.miss;
    }

    // Perfumer ("Nose") Comparison
    final MatchStatus perfumerStatus;
    if (guess.perfumer != 'Unknown' &&
        target.perfumer != 'Unknown' &&
        guess.perfumer.trim().isNotEmpty &&
        target.perfumer.trim().isNotEmpty &&
        StringNormalizer.normalizeForSearch(guess.perfumer) ==
            StringNormalizer.normalizeForSearch(target.perfumer)) {
      perfumerStatus = MatchStatus.exact;
    } else {
      perfumerStatus = MatchStatus.miss;
    }

    // Olfactory Notes Intersection
    final commonNoteKeys =
        guess.normalizedNotesSet.intersection(target.normalizedNotesSet);
    final sharedNotesList = commonNoteKeys
        .map((k) =>
            target.normalizedToDisplayNote[k] ??
            guess.normalizedToDisplayNote[k] ??
            StringNormalizer.formatNoteDisplay(k))
        .toList()
      ..sort((a, b) => a.compareTo(b));

    final MatchStatus notesStatus;
    if (sharedNotesList.length >= 4 ||
        (target.normalizedNotesSet.isNotEmpty &&
            sharedNotesList.length >=
                (target.normalizedNotesSet.length * 0.5).ceil())) {
      notesStatus = MatchStatus.exact;
    } else if (sharedNotesList.isNotEmpty) {
      notesStatus = MatchStatus.close;
    } else {
      notesStatus = MatchStatus.miss;
    }

    // Main Accords Comparison (Top 5)
    final guessAccords5 = guess.accords.take(5).map((a) => a.toLowerCase()).toSet();
    final targetAccords5 = target.accords.take(5).map((a) => a.toLowerCase()).toSet();
    final commonAccords = guessAccords5.intersection(targetAccords5).toList();

    final bool topAccordMatch = guess.accords.isNotEmpty &&
        target.accords.isNotEmpty &&
        guess.accords.first.toLowerCase().trim() ==
            target.accords.first.toLowerCase().trim();

    final MatchStatus accordsStatus;
    if (topAccordMatch || commonAccords.length >= 3) {
      accordsStatus = MatchStatus.exact;
    } else if (commonAccords.isNotEmpty) {
      accordsStatus = MatchStatus.close;
    } else {
      accordsStatus = MatchStatus.miss;
    }

    return GuessResult(
      guessedPerfume: guess,
      isCorrect: isCorrect,
      isFlankerMatch: isFlankerMatch,
      brandStatus: brandStatus,
      yearStatus: yearStatus,
      yearDirection: yearDirection,
      genderStatus: genderStatus,
      perfumerStatus: perfumerStatus,
      sharedNotes: sharedNotesList,
      notesStatus: notesStatus,
      sharedAccords: commonAccords,
      topAccordExactMatch: topAccordMatch,
      accordsStatus: accordsStatus,
    );
  }

  /// Numeric score for 1v1 tie-breakers and leaderboard accuracy.
  int get closenessScore {
    if (isCorrect) return 100;
    int score = isFlankerMatch ? 8 : 0;
    score += _pts(brandStatus);
    score += _pts(yearStatus);
    score += _pts(genderStatus);
    score += _pts(perfumerStatus);
    score += _pts(accordsStatus);
    score += _pts(notesStatus);
    score += sharedNotes.length;
    return score;
  }

  static int _pts(MatchStatus s) {
    switch (s) {
      case MatchStatus.exact:
        return 3;
      case MatchStatus.close:
        return 1;
      case MatchStatus.miss:
        return 0;
    }
  }

  /// 4-element status row for live spoiler-free 1v1 sync: [Brand, Year, Accords, Notes].
  List<String> get multiplayerColorRow => [
        _statusStr(brandStatus),
        _statusStr(yearStatus),
        _statusStr(accordsStatus),
        _statusStr(notesStatus),
      ];

  static String _statusStr(MatchStatus s) {
    switch (s) {
      case MatchStatus.exact:
        return 'EXACT';
      case MatchStatus.close:
        return 'CLOSE';
      case MatchStatus.miss:
        return 'MISS';
    }
  }
}
