import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../core/utils/string_normalizer.dart';
import '../models/clue_state.dart';
import '../models/guess_result.dart';
import '../models/perfume_model.dart';
import '../models/turn_entry.dart';
import '../models/user_stats.dart';
import '../services/game_engine_service.dart';
import '../services/network_time_service.dart';
import '../services/notification_service.dart';
import '../services/perfume_repository.dart';
import '../services/storage_service.dart';

enum GameMode {
  daily,
  unlimited,
}

/// Central state manager for Scentle single-player gameplay,
/// progressive clues, turn evaluation, persistence, and viral sharing.
class GameProvider extends ChangeNotifier {
  final PerfumeRepository _repository;
  final StorageService _storage;
  final GameEngineService _engine;

  GameProvider({
    PerfumeRepository? repository,
    StorageService? storage,
    GameEngineService? engine,
  })  : _repository = repository ?? PerfumeRepository.instance,
        _storage = storage ?? StorageService.instance,
        _engine = engine ?? const GameEngineService();

  GameMode _currentMode = GameMode.daily;
  GameMode get currentMode => _currentMode;

  late PerfumeModel _targetPerfume;
  PerfumeModel get targetPerfume => _targetPerfume;

  int _puzzleNumber = 1;
  int get puzzleNumber => _puzzleNumber;

  String _activeDateStr = '';
  String get activeDateStr => _activeDateStr;

  final List<TurnEntry> _turnEntries = [];
  List<TurnEntry> get turnEntries => List.unmodifiable(_turnEntries);

  final Set<int> _guessedPerfumeIds = {};
  Set<int> get guessedPerfumeIds => Set.unmodifiable(_guessedPerfumeIds);

  final Set<String> _discoveredNotesLower = {};
  Set<String> get discoveredNotesLower =>
      Set.unmodifiable(_discoveredNotesLower);

  final List<String> _bonusRevealedNotes = [];
  List<String> get bonusRevealedNotes =>
      List.unmodifiable(_bonusRevealedNotes);

  bool _bonusHintUsed = false;
  bool get bonusHintUsed => _bonusHintUsed;

  bool _isWon = false;
  bool get isWon => _isWon;

  bool _isLost = false;
  bool get isLost => _isLost;

  bool get isGameOver => _isWon || _isLost;

  /// Returns whether today's Daily Scentle has been solved or exhausted.
  bool get isDailyCompleted {
    if (_currentMode == GameMode.daily) {
      return isGameOver;
    }
    final saved = _storage.getDailyProgress(_activeDateStr);
    return saved != null && (saved['isGameOver'] as bool? ?? false);
  }

  late UserStats _userStats;
  UserStats get userStats => _userStats;

  final Set<int> _recentUnlimitedIds = {};

  /// Current progressive clue unlock state.
  ClueState get clueState {
    final mistakes = _turnEntries.where((e) {
      if (e.isSkip) return true;
      return e.guessResult != null && !e.guessResult!.isCorrect;
    }).length;

    return ClueState(
      target: _targetPerfume,
      mistakesCount: mistakes,
      isGameOver: isGameOver,
      discoveredNotesLower: _discoveredNotesLower,
      bonusRevealedNotes: _bonusRevealedNotes,
    );
  }

  // ===========================================================================
  // Game Initialization
  // ===========================================================================

  /// Starts or resumes the Daily puzzle for the specified date (defaults to UTC today).
  Future<void> startDailyGame({DateTime? utcNowOverride}) async {
    _currentMode = GameMode.daily;
    _userStats = _storage.getUserStats();

    final nowUtc = (utcNowOverride ?? NetworkTimeService.instance.getVerifiedUtcDate());
    final yearStr = nowUtc.year.toString().padLeft(4, '0');
    final monthStr = nowUtc.month.toString().padLeft(2, '0');
    final dayStr = nowUtc.day.toString().padLeft(2, '0');
    _activeDateStr = '$yearStr-$monthStr-$dayStr';

    _puzzleNumber = _repository.getDailyPuzzleNumber(nowUtc);
    _targetPerfume = _repository.getDailyTarget(nowUtc);

    _turnEntries.clear();
    _guessedPerfumeIds.clear();
    _discoveredNotesLower.clear();
    _bonusRevealedNotes.clear();
    _bonusHintUsed = false;
    _isWon = false;
    _isLost = false;

    // Check for saved progress in Hive
    final saved = _storage.getDailyProgress(_activeDateStr);
    if (saved != null) {
      _bonusHintUsed = saved['bonusNoteRevealed'] as bool? ?? false;

      final rawEntries = saved['entries'] as List<dynamic>? ?? const [];
      for (final e in rawEntries) {
        if (e is Map) {
          final type = e['type']?.toString();
          final turnNum = (e['turnNumber'] as int?) ?? (_turnEntries.length + 1);

          if (type == 'guess') {
            final pid = e['perfumeId'] as int?;
            if (pid != null) {
              final guessed = _repository.getById(pid);
              if (guessed != null) {
                final entry = _engine.createGuessEntry(
                  turnNumber: turnNum,
                  guess: guessed,
                  target: _targetPerfume,
                );
                _turnEntries.add(entry);
                _guessedPerfumeIds.add(guessed.id);
                _discoveredNotesLower.addAll(
                  entry.guessResult!.sharedNotes.map(StringNormalizer.normalizeNoteKey),
                );
              }
            }
          } else if (type == 'skip') {
            _turnEntries.add(_engine.createSkipEntry(turnNum));
          }
        }
      }

      _isWon = saved['isWon'] as bool? ?? false;
      final isOver = saved['isGameOver'] as bool? ?? false;
      _isLost = !isWon && (isOver || _turnEntries.length >= 6);
    }

    unawaited(NotificationService.instance.scheduleDailyStreakReminder(
      todayCompleted: isGameOver,
      currentStreak: _userStats.currentStreak,
    ));

    notifyListeners();
  }

  /// Starts a fresh game in Unlimited practice mode.
  void startUnlimitedGame() {
    _currentMode = GameMode.unlimited;
    _userStats = _storage.getUserStats();

    final nowUtc = DateTime.now().toUtc();
    final yearStr = nowUtc.year.toString().padLeft(4, '0');
    final monthStr = nowUtc.month.toString().padLeft(2, '0');
    final dayStr = nowUtc.day.toString().padLeft(2, '0');
    _activeDateStr = '$yearStr-$monthStr-$dayStr';

    _targetPerfume = _repository.getRandomMysteryTarget(
      excludeIds: _recentUnlimitedIds,
    );
    _recentUnlimitedIds.add(_targetPerfume.id);
    if (_recentUnlimitedIds.length > 20) {
      _recentUnlimitedIds.remove(_recentUnlimitedIds.first);
    }

    _turnEntries.clear();
    _guessedPerfumeIds.clear();
    _discoveredNotesLower.clear();
    _bonusRevealedNotes.clear();
    _bonusHintUsed = false;
    _isWon = false;
    _isLost = false;

    notifyListeners();
  }

  // ===========================================================================
  // Player Actions
  // ===========================================================================

  /// Submits a perfume guess for evaluation.
  Future<void> submitGuess(PerfumeModel perfume) async {
    if (isGameOver || _turnEntries.length >= 6) return;
    if (_guessedPerfumeIds.contains(perfume.id)) return;

    final turnNum = _turnEntries.length + 1;
    final entry = _engine.createGuessEntry(
      turnNumber: turnNum,
      guess: perfume,
      target: _targetPerfume,
    );

    _turnEntries.add(entry);
    _guessedPerfumeIds.add(perfume.id);

    final res = entry.guessResult!;
    _discoveredNotesLower.addAll(
      res.sharedNotes.map(StringNormalizer.normalizeNoteKey),
    );

    if (res.isCorrect) {
      _isWon = true;
      _userStats.recordGameWon(
        utcDateStr: _activeDateStr,
        turnCount: _turnEntries.length,
      );
      await _storage.saveUserStats(_userStats);
      await _storage.unlockPerfumeInCabinet(
        _targetPerfume.id,
        mode: _currentMode.name,
      );
    } else if (_turnEntries.length >= 6) {
      _isLost = true;
      _userStats.recordGameLost(utcDateStr: _activeDateStr);
      await _storage.saveUserStats(_userStats);
    }

    if (_currentMode == GameMode.daily) {
      await _persistDailyProgress();
      if (isGameOver) {
        unawaited(NotificationService.instance.scheduleDailyStreakReminder(
          todayCompleted: true,
          currentStreak: _userStats.currentStreak,
        ));
      }
    }
    notifyListeners();
  }

  /// Skips the active turn to intentionally unlock the next clue tier.
  Future<void> skipTurn() async {
    if (isGameOver || _turnEntries.length >= 6) return;

    final turnNum = _turnEntries.length + 1;
    _turnEntries.add(_engine.createSkipEntry(turnNum));

    if (_turnEntries.length >= 6) {
      _isLost = true;
      _userStats.recordGameLost(utcDateStr: _activeDateStr);
      await _storage.saveUserStats(_userStats);
    }

    if (_currentMode == GameMode.daily) {
      await _persistDailyProgress();
      if (isGameOver) {
        unawaited(NotificationService.instance.scheduleDailyStreakReminder(
          todayCompleted: true,
          currentStreak: _userStats.currentStreak,
        ));
      }
    }

    notifyListeners();
  }

  /// Uses the 1-time bonus note hint to reveal a random unrevealed note.
  Future<String?> useBonusNoteHint() async {
    if (_bonusHintUsed || isGameOver) return null;

    final allTargetNotes = _targetPerfume.notes.allRawNotes;
    final unrevealed = allTargetNotes.where((n) {
      final key = StringNormalizer.normalizeNoteKey(n);
      return !_discoveredNotesLower.contains(key);
    }).toList();

    if (unrevealed.isEmpty) return null;

    final picked = unrevealed[Random().nextInt(unrevealed.length)];
    final formatted = StringNormalizer.formatNoteDisplay(picked);

    _bonusRevealedNotes.add(formatted);
    _discoveredNotesLower.add(StringNormalizer.normalizeNoteKey(picked));
    _bonusHintUsed = true;

    if (_currentMode == GameMode.daily) {
      await _persistDailyProgress();
    }

    notifyListeners();
    return formatted;
  }

  Future<void> _persistDailyProgress() async {
    await _storage.saveDailyProgress(
      dateStr: _activeDateStr,
      targetId: _targetPerfume.id,
      entries: _turnEntries.map((e) => e.toJson()).toList(),
      isWon: _isWon,
      isGameOver: isGameOver,
      bonusNoteRevealed: _bonusHintUsed,
    );
  }

  // ===========================================================================
  // Viral Share String Builder
  // ===========================================================================

  /// Formats a spoiler-free, emoji-rich summary of the session for social sharing.
  String generateShareText() {
    final buffer = StringBuffer();

    // 1. Header
    if (_currentMode == GameMode.daily) {
      buffer.writeln(
        'Scentle #$_puzzleNumber 🧪 ${_isWon ? '${_turnEntries.length}/6' : 'X/6'}',
      );
    } else {
      buffer.writeln(
        'Scentle Atelier 🧪 ${_isWon ? '${_turnEntries.length}/6' : 'X/6'} (${_targetPerfume.displayTitle})',
      );
    }

    // 2. Turn by turn breakdown
    for (final entry in _turnEntries) {
      if (entry.isSkip) {
        buffer.writeln('⏭️ Skipped (+1 Clue)');
      } else {
        final res = entry.guessResult!;
        final bEmoji = _statusEmoji(res.brandStatus);
        final yEmoji = _statusEmoji(res.yearStatus);
        final dArrow = _dirArrow(res.yearDirection);
        final aEmoji = _statusEmoji(res.accordsStatus);
        final nEmoji = _statusEmoji(res.notesStatus);
        final flankerTag = res.isFlankerMatch ? ' 🔥Flanker!' : '';

        buffer.writeln(
          '🏢$bEmoji 📅$yEmoji$dArrow 🎨$aEmoji 🌿$nEmoji (${res.sharedNotes.length} notes)$flankerTag',
        );
      }
    }

    // 3. Footer
    buffer.write('🔥 Streak: ${_userStats.currentStreak}');
    return buffer.toString();
  }

  static String _statusEmoji(MatchStatus s) {
    switch (s) {
      case MatchStatus.exact:
        return '🟩';
      case MatchStatus.close:
        return '🟨';
      case MatchStatus.miss:
        return '⬜';
    }
  }

  static String _dirArrow(YearDirection d) {
    switch (d) {
      case YearDirection.newer:
        return '↑';
      case YearDirection.older:
        return '↓';
      case YearDirection.equal:
        return '';
    }
  }
}
