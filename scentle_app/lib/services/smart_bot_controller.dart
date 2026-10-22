import 'dart:async';
import 'dart:math';
import '../core/utils/string_normalizer.dart';
import '../models/guess_result.dart';
import '../models/multiplayer_room.dart';
import '../models/perfume_model.dart';
import 'game_engine_service.dart';
import 'multiplayer_transport.dart';
import 'perfume_repository.dart';

/// Intelligent database-driven AI opponent for 1v1 speed duels.
/// Selects genuine [PerfumeModel] records from [PerfumeRepository] using
/// progressive olfactory deduction heuristics across turns 1 to 6.
class SmartBotController {
  final String botId;
  final String nickname;
  final int elo;
  final PerfumeRepository repository;
  final GameEngineService engine;
  final MultiplayerTransport transport;
  final Duration? customStepDelay;
  final Random random;

  bool _isStopped = false;
  final List<PerfumeModel> _botGuesses = [];
  final List<GuessResult> _botResults = [];

  SmartBotController({
    required this.botId,
    required this.nickname,
    required this.elo,
    required this.repository,
    required this.engine,
    required this.transport,
    this.customStepDelay,
    Random? random,
  }) : random = random ?? Random();

  List<PerfumeModel> get botGuesses => List.unmodifiable(_botGuesses);
  List<GuessResult> get botResults => List.unmodifiable(_botResults);
  bool get isStopped => _isStopped;

  // ===========================================================================
  // Curated 40 Fragrance Enthusiast Handles
  // ===========================================================================

  static const List<String> enthusiastNicknames = [
    'AmbroxanAddict',
    'ChypreQueen',
    'GourmandGuy',
    'OudVoyager',
    'VetiverVagabond',
    'SillageSeeker',
    'NicheNose',
    'FlaconFanatic',
    'DrydownDan',
    'IrisEnthusiast',
    'PatchouliPrince',
    'BergamotBoy',
    'VanillaVesper',
    'LeatherLover',
    'MuskMystic',
    'CedarConnoisseur',
    'NeroliKnight',
    'AmberArtisan',
    'CardamomCount',
    'TonkaTraveller',
    'IncenseInquirer',
    'SantalScholar',
    'CivetCollector',
    'AquaticAlchemist',
    'AldehydeAce',
    'RoseRenaissance',
    'VetiverVirtuoso',
    'CologneCurator',
    'GourmandGoddess',
    'FougerePhilosopher',
    'FloralFlaneur',
    'ResinRambler',
    'SmokySommelier',
    'TobaccoTaster',
    'CitrusCentric',
    'SpiceSavant',
    'OakmossOracle',
    'PetrichorProwler',
    'BenzoinBaron',
    'GuanajuatoGourmet',
  ];

  /// Factory creating a calibrated bot opponent with ELO ±120 of the player.
  factory SmartBotController.create({
    required int playerElo,
    PerfumeRepository? repository,
    GameEngineService? engine,
    MultiplayerTransport? transport,
    Duration? customStepDelay,
    Random? random,
  }) {
    final rand = random ?? Random();
    final name = enthusiastNicknames[rand.nextInt(enthusiastNicknames.length)];
    final botId = 'bot_${rand.nextInt(90000) + 10000}';
    final eloDelta = rand.nextInt(241) - 120; // -120 to +120
    final botElo = (playerElo + eloDelta).clamp(800, 2400);

    return SmartBotController(
      botId: botId,
      nickname: name,
      elo: botElo,
      repository: repository ?? PerfumeRepository.instance,
      engine: engine ?? const GameEngineService(),
      transport: transport ?? MultiplayerTransport.createDefault(),
      customStepDelay: customStepDelay,
      random: rand,
    );
  }

  // ===========================================================================
  // Progressive Olfactory Deduction Heuristics
  // ===========================================================================

  /// Selects a genuine [PerfumeModel] guess from the repository according to turn heuristics.
  PerfumeModel selectGuess({
    required int turn,
    required PerfumeModel target,
    required Set<int> previousGuessIds,
  }) {
    final mysteryPool = repository.mysteryPool;
    final searchable = repository.allPerfumes;

    // Helper: exclude already guessed perfumes and target unless intentionally solving
    List<PerfumeModel> filterAvailable(Iterable<PerfumeModel> list) {
      return list.where((p) => p.id != target.id && !previousGuessIds.contains(p.id)).toList();
    }

    final targetAccordsLower = target.accords.map((a) => a.toLowerCase().trim()).toSet();
    final targetNotesNormalized = target.notes.allRawNotes
        .map(StringNormalizer.normalizeNoteKey)
        .where((k) => k.isNotEmpty)
        .toSet();

    switch (turn) {
      case 1:
        // Turn 1 (Opening Probe): Same gender & at least 1 shared accord from mystery pool
        final candidates = filterAvailable(mysteryPool.where((p) {
          final genderMatch = p.gender.toLowerCase() == target.gender.toLowerCase() ||
              p.gender.toLowerCase() == 'unisex' ||
              target.gender.toLowerCase() == 'unisex';
          final accordMatch = p.accords.any((a) => targetAccordsLower.contains(a.toLowerCase().trim()));
          return genderMatch && accordMatch;
        }));

        if (candidates.isNotEmpty) {
          // Prefer higher-voted popular fragrances
          candidates.sort((a, b) => b.votes.compareTo(a.votes));
          final topSlice = candidates.take(min(15, candidates.length)).toList();
          return topSlice[random.nextInt(topSlice.length)];
        }
        break;

      case 2:
        // Turn 2 (Accord Alignment): Shared notes or release year within ±8 years
        final candidates = filterAvailable(mysteryPool.where((p) {
          final yearNear = (target.year > 0 && p.year > 0) && (p.year - target.year).abs() <= 8;
          final noteMatch = p.notes.allRawNotes.any((n) {
            final key = StringNormalizer.normalizeNoteKey(n);
            return key.isNotEmpty && targetNotesNormalized.contains(key);
          });
          return yearNear || noteMatch;
        }));

        if (candidates.isNotEmpty) {
          candidates.sort((a, b) => b.votes.compareTo(a.votes));
          final topSlice = candidates.take(min(20, candidates.length)).toList();
          return topSlice[random.nextInt(topSlice.length)];
        }
        break;

      case 3:
      case 4:
        // Turn 3 & 4 (Pyramid Convergence): 15% probability of solving target
        if (random.nextDouble() < 0.15) {
          return target;
        }

        // Filters for country, brand, or >= 2 shared notes
        final candidates = filterAvailable(mysteryPool.where((p) {
          final sameBrand = p.normalizedBrand == target.normalizedBrand;
          final sameCountry = target.country.isNotEmpty &&
              target.country != 'Unknown' &&
              p.country.toLowerCase() == target.country.toLowerCase();
          final sharedNotesCount = p.notes.allRawNotes
              .map(StringNormalizer.normalizeNoteKey)
              .where((k) => k.isNotEmpty && targetNotesNormalized.contains(k))
              .length;
          return sameBrand || sameCountry || sharedNotesCount >= 2;
        }));

        if (candidates.isNotEmpty) {
          return candidates[random.nextInt(candidates.length)];
        }
        break;

      case 5:
        // Turn 5 (Close Encounter): 35% probability of solving target
        if (random.nextDouble() < 0.35) {
          return target;
        }

        // Pick highest note overlap or flanker
        final candidates = filterAvailable(mysteryPool.where((p) {
          final isSameBrand = p.normalizedBrand == target.normalizedBrand;
          final sharedCount = p.notes.allRawNotes
              .map(StringNormalizer.normalizeNoteKey)
              .where((k) => k.isNotEmpty && targetNotesNormalized.contains(k))
              .length;
          return isSameBrand || sharedCount >= 2;
        }));

        if (candidates.isNotEmpty) {
          // Sort descending by shared notes count
          candidates.sort((a, b) {
            final aNotes = a.notes.allRawNotes.map(StringNormalizer.normalizeNoteKey).where(targetNotesNormalized.contains).length;
            final bNotes = b.notes.allRawNotes.map(StringNormalizer.normalizeNoteKey).where(targetNotesNormalized.contains).length;
            return bNotes.compareTo(aNotes);
          });
          return candidates.first;
        }
        break;

      case 6:
      default:
        // Turn 6 (Final Climax): 55% probability of solving target
        if (random.nextDouble() < 0.55) {
          return target;
        }

        // Otherwise pick best available candidate
        final candidates = filterAvailable(mysteryPool);
        if (candidates.isNotEmpty) {
          candidates.sort((a, b) {
            final aNotes = a.notes.allRawNotes.map(StringNormalizer.normalizeNoteKey).where(targetNotesNormalized.contains).length;
            final bNotes = b.notes.allRawNotes.map(StringNormalizer.normalizeNoteKey).where(targetNotesNormalized.contains).length;
            return bNotes.compareTo(aNotes);
          });
          return candidates.first;
        }
        break;
    }

    // Defensive fallback: any un-guessed fragrance from mysteryPool or searchable
    final fallbackPool = filterAvailable(mysteryPool);
    if (fallbackPool.isNotEmpty) {
      return fallbackPool[random.nextInt(fallbackPool.length)];
    }

    final globalFallback = filterAvailable(searchable);
    if (globalFallback.isNotEmpty) {
      return globalFallback[random.nextInt(globalFallback.length)];
    }

    // Absolute fallback: target itself if exhausted
    return target;
  }

  // ===========================================================================
  // Asynchronous Bot Duel Runner
  // ===========================================================================

  /// Starts the bot turn loop, simulating human thinking delays and updating room state.
  Future<void> runBotTurnLoop({
    required String roomCode,
    required PerfumeModel target,
    void Function(PerfumeModel guess)? onGuessMade,
  }) async {
    _isStopped = false;
    final previousIds = <int>{};

    for (int turn = 1; turn <= 6; turn++) {
      if (_isStopped) break;

      // Realistic delay (9-15s) or rapid step delay for tests
      final delay = customStepDelay ?? Duration(seconds: 9 + random.nextInt(7));
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      if (_isStopped) break;

      // Check current room status
      final latestRoom = await transport.fetchRoom(roomCode);
      if (latestRoom == null || latestRoom.status != 'playing') {
        break;
      }

      final botState = latestRoom.players[botId];
      if (botState == null || botState.solved || botState.exhaustedTurns) {
        break;
      }

      // If human opponent already solved, match is over
      final humanOpponent = latestRoom.opponentOf(botId);
      if (humanOpponent != null && humanOpponent.solved) {
        break;
      }

      // Select and evaluate deduction guess
      final guess = selectGuess(
        turn: turn,
        target: target,
        previousGuessIds: previousIds,
      );

      previousIds.add(guess.id);
      _botGuesses.add(guess);

      final evalResult = engine.evaluateGuess(guess, target);
      _botResults.add(evalResult);

      final isSolved = evalResult.isCorrect;
      final isExhausted = turn >= 6 && !isSolved;
      final closeness = evalResult.closenessScore;
      final newBestCloseness = max(botState.bestClosenessScore, closeness);

      final updatedGrid = List<List<String>>.from(botState.colorGrid)
        ..add(evalResult.multiplayerColorRow);
      final updatedIds = List<int>.from(botState.guessedPerfumeIds)..add(guess.id);

      final updatedBot = botState.copyWith(
        turnCount: turn,
        solved: isSolved,
        exhaustedTurns: isExhausted,
        bestClosenessScore: newBestCloseness,
        colorGrid: updatedGrid,
        guessedPerfumeIds: updatedIds,
        lastActionEpochMs: DateTime.now().millisecondsSinceEpoch,
      );

      onGuessMade?.call(guess);

      if (isSolved) {
        // Immediate Victory for Bot
        final updatedPlayers = Map<String, MultiplayerPlayerState>.from(latestRoom.players);
        updatedPlayers[botId] = updatedBot;

        final finishedRoom = latestRoom.copyWith(
          status: 'finished',
          winnerId: botId,
          winReason: 'SOLVED_FIRST',
          players: updatedPlayers,
        );
        await transport.createOrUpdateRoom(finishedRoom);
        break;
      } else if (isExhausted && humanOpponent != null && humanOpponent.exhaustedTurns) {
        // Both exhausted: resolve by closeness score
        final updatedPlayers = Map<String, MultiplayerPlayerState>.from(latestRoom.players);
        updatedPlayers[botId] = updatedBot;

        final String winnerId;
        final String winReason;
        if (newBestCloseness > humanOpponent.bestClosenessScore) {
          winnerId = botId;
          winReason = 'CLOSEST_AFTER_EXHAUSTION';
        } else if (humanOpponent.bestClosenessScore > newBestCloseness) {
          winnerId = humanOpponent.playerId;
          winReason = 'CLOSEST_AFTER_EXHAUSTION';
        } else {
          winnerId = 'DRAW';
          winReason = 'DRAW';
        }

        final finishedRoom = latestRoom.copyWith(
          status: 'finished',
          winnerId: winnerId,
          winReason: winReason,
          players: updatedPlayers,
        );
        await transport.createOrUpdateRoom(finishedRoom);
        break;
      } else {
        // Normal turn sync
        await transport.patchPlayerState(roomCode, updatedBot);
      }
    }
  }

  /// Cancels any ongoing bot execution loop immediately.
  void stop() {
    _isStopped = true;
  }
}
