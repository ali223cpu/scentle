import 'package:flutter_test/flutter_test.dart';
import 'package:scentle_app/models/clue_state.dart';
import 'package:scentle_app/models/guess_result.dart';
import 'package:scentle_app/models/perfume_model.dart';
import 'package:scentle_app/providers/game_provider.dart';
import 'package:scentle_app/services/game_engine_service.dart';
import 'package:scentle_app/services/perfume_repository.dart';
import 'package:scentle_app/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PerfumeRepository repository;
  late StorageService storage;
  late GameEngineService engine;

  setUpAll(() async {
    repository = PerfumeRepository.instance;
    await repository.initialize();

    storage = StorageService.instance;
    await storage.initialize();

    engine = const GameEngineService();
  });

  tearDown(() async {
    await storage.clearAllBoxesForTesting();
  });

  group('GameEngine & GuessResult Tests', () {
    test('1. Exact vs. Flanker Evaluation: Sauvage Elixir vs Sauvage EDT', () {
      final sauvageEdt = repository.getById(151345);
      expect(sauvageEdt, isNotNull);

      // Find Sauvage Elixir in repository
      final elixir = repository.allPerfumes.firstWhere(
        (p) => p.name == 'Sauvage Elixir' && p.brand == 'Dior',
      );
      expect(elixir, isNotNull);

      // 1A. Evaluate Elixir against EDT (Flanker Match)
      final flankerResult = engine.evaluateGuess(elixir, sauvageEdt!);
      expect(flankerResult.isCorrect, isFalse);
      expect(flankerResult.isFlankerMatch, isTrue);
      expect(flankerResult.brandStatus, MatchStatus.exact);
      expect(flankerResult.sharedNotes.isNotEmpty, isTrue);
      expect(flankerResult.sharedAccords.isNotEmpty, isTrue);
      expect(flankerResult.closenessScore, greaterThan(8));
      expect(flankerResult.multiplayerColorRow.length, 4);

      // 1B. Evaluate EDT against EDT (Exact Match)
      final exactResult = engine.evaluateGuess(sauvageEdt, sauvageEdt);
      expect(exactResult.isCorrect, isTrue);
      expect(exactResult.isFlankerMatch, isFalse);
      expect(exactResult.brandStatus, MatchStatus.exact);
      expect(exactResult.yearStatus, MatchStatus.exact);
      expect(exactResult.yearDirection, YearDirection.equal);
      expect(exactResult.genderStatus, MatchStatus.exact);
      expect(exactResult.closenessScore, 100);
    });

    test('2. Year Direction Math: Guessing 2010 when target is 2015 returns close & newer (↑)', () {
      final target = repository.getById(151345)!; // Year: 2015
      expect(target.year, 2015);

      final dummyGuess2010 = PerfumeModel(
        id: 99901,
        name: 'Older Fragrance',
        brand: 'Chanel',
        year: 2010,
        notes: const NotePyramid(top: [], middle: [], base: []),
      );

      final result2010 = engine.evaluateGuess(dummyGuess2010, target);
      expect(result2010.yearStatus, MatchStatus.close);
      expect(result2010.yearDirection, YearDirection.newer);

      final dummyGuess2020 = PerfumeModel(
        id: 99902,
        name: 'Newer Fragrance',
        brand: 'Chanel',
        year: 2020,
        notes: const NotePyramid(top: [], middle: [], base: []),
      );

      final result2020 = engine.evaluateGuess(dummyGuess2020, target);
      expect(result2020.yearStatus, MatchStatus.close);
      expect(result2020.yearDirection, YearDirection.older);

      final dummyGuess1990 = PerfumeModel(
        id: 99903,
        name: 'Vintage Fragrance',
        brand: 'Chanel',
        year: 1990,
        notes: const NotePyramid(top: [], middle: [], base: []),
      );

      final result1990 = engine.evaluateGuess(dummyGuess1990, target);
      expect(result1990.yearStatus, MatchStatus.miss);
      expect(result1990.yearDirection, YearDirection.newer);
    });

    test('3. Progressive Clue Unlocking across mistakes 0 to 5 and Game Over', () {
      final target = repository.getById(151345)!; // Sauvage Dior

      // Turn 1 (0 mistakes)
      final clue0 = ClueState(target: target, mistakesCount: 0, isGameOver: false);
      expect(clue0.currentTurnNumber, 1);
      expect(clue0.mainAccords, isNotEmpty);
      expect(clue0.gender, 'Men');
      expect(clue0.isTopNotesUnlocked, isFalse);
      expect(clue0.topNotes, isEmpty);
      expect(clue0.releaseDecade, isNull);
      expect(clue0.brand, isNull);
      expect(clue0.showBottleImage, isFalse);
      expect(clue0.fullPerfumeName, isNull);

      // Turn 2 (1 mistake): Top Notes + Decade
      final clue1 = ClueState(target: target, mistakesCount: 1, isGameOver: false);
      expect(clue1.currentTurnNumber, 2);
      expect(clue1.isTopNotesUnlocked, isTrue);
      expect(clue1.topNotes, isNotEmpty);
      expect(clue1.releaseDecade, '2010s');
      expect(clue1.isMiddleNotesUnlocked, isFalse);

      // Turn 3 (2 mistakes): Middle Notes + Country
      final clue2 = ClueState(target: target, mistakesCount: 2, isGameOver: false);
      expect(clue2.currentTurnNumber, 3);
      expect(clue2.isMiddleNotesUnlocked, isTrue);
      expect(clue2.middleNotes, isNotEmpty);
      expect(clue2.country, 'France');
      expect(clue2.isBaseNotesUnlocked, isFalse);

      // Turn 4 (3 mistakes): Base Notes + Perfumer
      final clue3 = ClueState(target: target, mistakesCount: 3, isGameOver: false);
      expect(clue3.currentTurnNumber, 4);
      expect(clue3.isBaseNotesUnlocked, isTrue);
      expect(clue3.baseNotes, isNotEmpty);
      expect(clue3.perfumer, 'François Demachy');
      expect(clue3.brand, isNull);

      // Turn 5 (4 mistakes): Brand + Exact Year
      final clue4 = ClueState(target: target, mistakesCount: 4, isGameOver: false);
      expect(clue4.currentTurnNumber, 5);
      expect(clue4.brand, 'Dior');
      expect(clue4.exactYear, 2015);
      expect(clue4.showBottleImage, isFalse);

      // Turn 6 (5 mistakes): Silhouette preview with blur 18.0
      final clue5 = ClueState(target: target, mistakesCount: 5, isGameOver: false);
      expect(clue5.currentTurnNumber, 6);
      expect(clue5.showBottleImage, isTrue);
      expect(clue5.blurSigma, 18.0);
      expect(clue5.fullPerfumeName, isNull);

      // Game Over: Unblurred bottle + full name revealed
      final clueOver = ClueState(target: target, mistakesCount: 6, isGameOver: true);
      expect(clueOver.showBottleImage, isTrue);
      expect(clueOver.blurSigma, 0.0);
      expect(clueOver.fullPerfumeName, 'Sauvage');
      expect(clueOver.brand, 'Dior');
    });
  });

  group('GameProvider Daily Persistence & Streak Flow', () {
    test('4. Daily Persistence & Streak Restoration across provider reload', () async {
      final testDate = DateTime.utc(2026, 10, 18);

      final provider1 = GameProvider(
        repository: repository,
        storage: storage,
        engine: engine,
      );

      await provider1.startDailyGame(utcNowOverride: testDate);
      final target = provider1.targetPerfume;
      expect(provider1.turnEntries, isEmpty);

      // Make 1 wrong guess
      final wrongPerfume1 = repository.allPerfumes.firstWhere(
        (p) => p.id != target.id && p.brand != target.brand,
      );
      await provider1.submitGuess(wrongPerfume1);

      // Skip 1 turn
      await provider1.skipTurn();

      expect(provider1.turnEntries.length, 2);
      expect(provider1.clueState.currentTurnNumber, 3);
      expect(provider1.isGameOver, isFalse);

      // Simulate app restart: re-instantiate GameProvider on the same UTC day
      final provider2 = GameProvider(
        repository: repository,
        storage: storage,
        engine: engine,
      );

      await provider2.startDailyGame(utcNowOverride: testDate);

      // Invariants must be accurately restored from Hive
      expect(provider2.targetPerfume.id, target.id);
      expect(provider2.turnEntries.length, 2);
      expect(provider2.turnEntries[0].isGuess, isTrue);
      expect(provider2.turnEntries[0].guessResult!.guessedPerfume.id, wrongPerfume1.id);
      expect(provider2.turnEntries[1].isSkip, isTrue);
      expect(provider2.clueState.currentTurnNumber, 3);
      expect(provider2.guessedPerfumeIds.contains(wrongPerfume1.id), isTrue);

      // Submit correct answer to complete victory
      await provider2.submitGuess(target);

      expect(provider2.isWon, isTrue);
      expect(provider2.isGameOver, isTrue);
      expect(provider2.userStats.gamesWon, 1);
      expect(provider2.userStats.currentStreak, 1);
      expect(storage.isPerfumeInCabinet(target.id), isTrue);
      expect(storage.cabinetCount, greaterThanOrEqualTo(1));
    });

    test('5. Share Text Generation: Daily mode produces emoji grid without leaking name', () async {
      final provider = GameProvider(
        repository: repository,
        storage: storage,
        engine: engine,
      );

      await provider.startDailyGame(utcNowOverride: DateTime.utc(2026, 10, 18));
      final target = provider.targetPerfume;

      // Add a guess and a skip
      final wrongPerfume = repository.allPerfumes.firstWhere((p) => p.id != target.id);
      await provider.submitGuess(wrongPerfume);
      await provider.skipTurn();

      final shareText = provider.generateShareText();

      expect(shareText.contains('Scentle #${provider.puzzleNumber}'), isTrue);
      expect(shareText.contains('🏢'), isTrue);
      expect(shareText.contains('📅'), isTrue);
      expect(shareText.contains('🎨'), isTrue);
      expect(shareText.contains('🌿'), isTrue);
      expect(shareText.contains('⏭️ Skipped (+1 Clue)'), isTrue);
      expect(shareText.contains('🔥 Streak:'), isTrue);

      // Must NEVER leak the target perfume name in daily mode
      expect(shareText.contains(target.name), isFalse);
    });
  });
}
