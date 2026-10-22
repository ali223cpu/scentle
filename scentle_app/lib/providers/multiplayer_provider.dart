import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../core/config/app_config.dart';
import '../core/utils/string_normalizer.dart';
import '../models/clue_state.dart';
import '../models/multiplayer_room.dart';
import '../models/perfume_model.dart';
import '../models/turn_entry.dart';
import '../services/game_engine_service.dart';
import '../services/multiplayer_transport.dart';
import '../services/perfume_repository.dart';
import '../services/rank_service.dart';
import '../services/smart_bot_controller.dart';
import '../services/storage_service.dart';

/// Manages real-time 1v1 multiplayer duels, room matchmaking, match timer,
/// live opponent synchronization, and post-match ELO ranking.
class MultiplayerProvider extends ChangeNotifier {
  final MultiplayerTransport _transport;
  final GameEngineService _engine;
  final PerfumeRepository _repository;
  final StorageService _storage;
  final String? _overridePlayerId;

  MultiplayerProvider({
    String? playerId,
    MultiplayerTransport? transport,
    GameEngineService? engine,
    PerfumeRepository? repository,
    StorageService? storage,
  })  : _overridePlayerId = playerId,
        _transport = transport ?? MultiplayerTransport.createDefault(),
        _engine = engine ?? const GameEngineService(),
        _repository = repository ?? PerfumeRepository.instance,
        _storage = storage ?? StorageService.instance {
    _initializeIdentity();
  }

  // ===========================================================================
  // Local Player Identity
  // ===========================================================================

  late String _myPlayerId;
  late String _myNickname;

  String get myPlayerId => _myPlayerId;
  String get myNickname => _myNickname;

  void _initializeIdentity() {
    _myPlayerId = _overridePlayerId ?? _storage.getOrCreatePlayerId();
    _myNickname = _storage.getPlayerNickname();
  }

  Future<void> setNickname(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == _myNickname) return;
    _myNickname = trimmed;
    await _storage.savePlayerNickname(_myNickname);

    if (_currentRoom != null && _currentRoom!.players.containsKey(_myPlayerId)) {
      final me = _currentRoom!.players[_myPlayerId]!;
      await _transport.patchPlayerState(
        _currentRoom!.roomCode,
        me.copyWith(nickname: _myNickname),
      );
    }
    notifyListeners();
  }

  // ===========================================================================
  // Room State & Streaming
  // ===========================================================================

  MultiplayerRoom? _currentRoom;
  StreamSubscription<MultiplayerRoom?>? _roomSubscription;
  Timer? _matchTimer;
  Timer? _botTimer;

  int _remainingSeconds = AppConfig.matchDurationSeconds;
  bool _isConnecting = false;
  String? _errorMessage;
  int? _lastProcessedEloDelta;

  SmartBotController? _activeBotController;
  bool _isMatchmaking = false;
  int _matchmakingElapsedSeconds = 0;
  Timer? _matchmakingTimer;
  Timer? _matchmakingTicker;

  MultiplayerRoom? get currentRoom => _currentRoom;
  int get remainingSeconds => _remainingSeconds;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;
  int? get lastProcessedEloDelta => _lastProcessedEloDelta;
  bool get isMatchmaking => _isMatchmaking;
  int get matchmakingElapsedSeconds => _matchmakingElapsedSeconds;
  SmartBotController? get activeBotController => _activeBotController;

  MultiplayerPlayerState? get myState => _currentRoom?.players[_myPlayerId];

  MultiplayerPlayerState? get opponentState => _currentRoom?.opponentOf(_myPlayerId);

  // ===========================================================================
  // Local Game Board State (Synced with Target Perfume)
  // ===========================================================================

  PerfumeModel? _targetPerfume;
  final List<TurnEntry> _turnEntries = [];
  final Set<String> _discoveredNotesLower = {};
  final List<String> _bonusRevealedNotes = [];
  bool _bonusNoteRevealed = false;

  PerfumeModel? get targetPerfume => _targetPerfume;
  List<TurnEntry> get turnEntries => List.unmodifiable(_turnEntries);
  int get currentTurnNumber => (_turnEntries.length + 1).clamp(1, 6);
  bool get bonusNoteRevealed => _bonusNoteRevealed;

  ClueState get clueState {
    if (_targetPerfume == null) {
      return ClueState(
        target: PerfumeModel(
          id: 0,
          name: '',
          brand: '',
          notes: const NotePyramid(top: [], middle: [], base: []),
        ),
        mistakesCount: 0,
        isGameOver: false,
      );
    }

    final mistakes = _turnEntries.where((e) {
      if (e.isSkip) return true;
      return e.guessResult != null && !e.guessResult!.isCorrect;
    }).length;

    return ClueState(
      target: _targetPerfume!,
      mistakesCount: mistakes,
      isGameOver: _currentRoom?.status == 'finished',
      discoveredNotesLower: _discoveredNotesLower,
      bonusRevealedNotes: _bonusRevealedNotes,
    );
  }

  Set<int> get guessedPerfumeIds => _turnEntries
      .where((e) => e.isGuess && e.guessResult != null)
      .map((e) => e.guessResult!.guessedPerfume.id)
      .toSet();

  // ===========================================================================
  // Room Lifecycle: Create, Join, Leave
  // ===========================================================================

  /// Characters allowed in 4-character room codes (excluding ambiguous 0, O, 1, I).
  static const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String generateRoomCode() {
    final rand = Random();
    return List.generate(4, (_) => _codeAlphabet[rand.nextInt(_codeAlphabet.length)]).join();
  }

  /// Creates a private multiplayer room with a 4-character code.
  Future<String> createPrivateRoom({String? customNickname}) async {
    _isConnecting = true;
    _errorMessage = null;
    _lastProcessedEloDelta = null;
    notifyListeners();

    try {
      if (customNickname != null && customNickname.trim().isNotEmpty) {
        await setNickname(customNickname);
      }

      final roomCode = generateRoomCode();
      final mysteryPool = _repository.mysteryPool;
      if (mysteryPool.isEmpty) {
        throw StateError('Fragrance archive is unpopulated');
      }

      final target = mysteryPool[Random().nextInt(mysteryPool.length)];
      final stats = _storage.getUserStats();

      final hostState = MultiplayerPlayerState(
        playerId: _myPlayerId,
        nickname: _myNickname,
        elo: stats.eloRating,
        lastActionEpochMs: DateTime.now().millisecondsSinceEpoch,
      );

      final newRoom = MultiplayerRoom(
        roomCode: roomCode,
        isPublic: false,
        status: 'waiting',
        targetPerfumeId: target.id,
        createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        players: {_myPlayerId: hostState},
      );

      _currentRoom = newRoom;
      await _transport.createOrUpdateRoom(newRoom);
      _targetPerfume = target;
      _resetLocalBoard();

      await _subscribeToRoom(roomCode);
      _isConnecting = false;
      notifyListeners();
      return roomCode;
    } catch (e) {
      _isConnecting = false;
      _errorMessage = 'Failed to create room: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Joins an existing private room code.
  Future<bool> joinPrivateRoom(String roomCode, {String? customNickname}) async {
    final sanitizedCode = roomCode.trim().toUpperCase();
    if (sanitizedCode.length != 4) {
      _errorMessage = 'Room code must be 4 characters';
      notifyListeners();
      return false;
    }

    _isConnecting = true;
    _errorMessage = null;
    _lastProcessedEloDelta = null;
    notifyListeners();

    try {
      if (customNickname != null && customNickname.trim().isNotEmpty) {
        await setNickname(customNickname);
      }

      final existingRoom = await _transport.fetchRoom(sanitizedCode);
      if (existingRoom == null) {
        _errorMessage = 'Room "$sanitizedCode" not found';
        _isConnecting = false;
        notifyListeners();
        return false;
      }

      if (existingRoom.status != 'waiting') {
        _errorMessage = 'This duel has already started or ended';
        _isConnecting = false;
        notifyListeners();
        return false;
      }

      if (existingRoom.isFull && !existingRoom.players.containsKey(_myPlayerId)) {
        _errorMessage = 'This room is already full (2/2 players)';
        _isConnecting = false;
        notifyListeners();
        return false;
      }

      final stats = _storage.getUserStats();
      final myPlayerState = MultiplayerPlayerState(
        playerId: _myPlayerId,
        nickname: _myNickname,
        elo: stats.eloRating,
        lastActionEpochMs: DateTime.now().millisecondsSinceEpoch,
      );

      final updatedPlayers = Map<String, MultiplayerPlayerState>.from(existingRoom.players);
      updatedPlayers[_myPlayerId] = myPlayerState;

      // When 2nd player joins, start match immediately
      final updatedRoom = existingRoom.copyWith(
        status: 'playing',
        matchStartedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        players: updatedPlayers,
      );

      _currentRoom = updatedRoom;
      await _transport.createOrUpdateRoom(updatedRoom);
      _targetPerfume = _repository.getById(updatedRoom.targetPerfumeId);
      _resetLocalBoard();

      await _subscribeToRoom(sanitizedCode);
      _startMatchTimer();

      _isConnecting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isConnecting = false;
      _errorMessage = 'Failed to join duel: $e';
      notifyListeners();
      return false;
    }
  }

  /// Initiates a duel against a realistic database-driven AI opponent powered by [SmartBotController].
  Future<String> startBotMatch({
    Duration? botStepDelay,
    int? customTargetId,
  }) async {
    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final code = generateRoomCode();
      final mysteryPool = _repository.mysteryPool;
      final target = customTargetId != null
          ? _repository.getById(customTargetId)!
          : mysteryPool[Random().nextInt(mysteryPool.length)];

      _targetPerfume = target;
      _resetLocalBoard();

      final userStats = _storage.getUserStats();
      final botController = SmartBotController.create(
        playerElo: userStats.eloRating,
        repository: _repository,
        engine: _engine,
        transport: _transport,
        customStepDelay: botStepDelay,
      );
      _activeBotController = botController;

      final hostPlayer = MultiplayerPlayerState(
        playerId: _myPlayerId,
        nickname: _myNickname,
        elo: userStats.eloRating,
        lastActionEpochMs: DateTime.now().millisecondsSinceEpoch,
        isBot: false,
      );

      final botPlayer = MultiplayerPlayerState(
        playerId: botController.botId,
        nickname: botController.nickname,
        elo: botController.elo,
        lastActionEpochMs: DateTime.now().millisecondsSinceEpoch,
        isBot: true,
      );

      final room = MultiplayerRoom(
        roomCode: code,
        isPublic: false,
        status: 'playing',
        targetPerfumeId: target.id,
        createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        matchStartedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        players: {
          _myPlayerId: hostPlayer,
          botController.botId: botPlayer,
        },
      );

      _currentRoom = room;
      await _transport.createOrUpdateRoom(room);
      await _subscribeToRoom(code);
      _startMatchTimer();

      // Launch the AI Bot turn loop asynchronously
      unawaited(botController.runBotTurnLoop(
        roomCode: code,
        target: target,
      ));

      return code;
    } catch (e) {
      _errorMessage = 'Failed to launch bot match: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Backward-compatible alias for bot practice duels.
  Future<String> startSimulatedDuel({Duration? botStepDelay}) async {
    return startBotMatch(botStepDelay: botStepDelay);
  }

  /// Alias for joinPrivateRoom.
  Future<bool> joinRoom(String roomCode, {String? customNickname}) =>
      joinPrivateRoom(roomCode, customNickname: customNickname);

  /// Initiates public matchmaking: joins an existing open public room within <6s
  /// or falls back to an authentic [SmartBotController] opponent.
  Future<void> startQuickMatch({
    Duration queueTimeout = const Duration(seconds: 6),
    Duration? botTurnDelay,
  }) async {
    if (_isMatchmaking) return;

    _isConnecting = true;
    _isMatchmaking = true;
    _matchmakingElapsedSeconds = 0;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Search for open public rooms
      final openRooms = await _transport.findOpenPublicRooms();
      final joinableRooms = openRooms.where((r) => !r.players.containsKey(_myPlayerId)).toList();
      if (joinableRooms.isNotEmpty) {
        final targetRoom = joinableRooms.first;
        final joined = await joinPrivateRoom(targetRoom.roomCode);
        if (joined) {
          _isMatchmaking = false;
          _isConnecting = false;
          notifyListeners();
          return;
        }
      }

      // 2. No open room found: create a public room and start queue countdown
      final code = generateRoomCode();
      final mysteryPool = _repository.mysteryPool;
      final target = mysteryPool[Random().nextInt(mysteryPool.length)];
      _targetPerfume = target;
      _resetLocalBoard();

      final userStats = _storage.getUserStats();
      final hostPlayer = MultiplayerPlayerState(
        playerId: _myPlayerId,
        nickname: _myNickname,
        elo: userStats.eloRating,
        lastActionEpochMs: DateTime.now().millisecondsSinceEpoch,
        isBot: false,
      );

      final newRoom = MultiplayerRoom(
        roomCode: code,
        isPublic: true,
        status: 'waiting',
        targetPerfumeId: target.id,
        createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        players: {_myPlayerId: hostPlayer},
      );

      _currentRoom = newRoom;
      await _transport.createOrUpdateRoom(newRoom);
      await _subscribeToRoom(code);

      _isConnecting = false;
      notifyListeners();

      // 3. Start ticker for UI radar
      _matchmakingTicker?.cancel();
      _matchmakingTicker = Timer.periodic(const Duration(seconds: 1), (ticker) {
        if (!_isMatchmaking) {
          ticker.cancel();
          return;
        }
        _matchmakingElapsedSeconds++;
        notifyListeners();
      });

      // 4. Start queue countdown timer (default 6 seconds)
      _matchmakingTimer?.cancel();
      _matchmakingTimer = Timer(queueTimeout, () async {
        if (!_isMatchmaking || _currentRoom == null || _currentRoom!.roomCode != code) {
          return;
        }

        final latest = await _transport.fetchRoom(code);
        // If a human joined while waiting, cancel bot fallback
        if (latest != null && latest.players.length >= 2) {
          _isMatchmaking = false;
          _matchmakingTicker?.cancel();
          notifyListeners();
          return;
        }

        // Timeout reached with no human player -> Spawn SmartBotController!
        _isMatchmaking = false;
        _matchmakingTicker?.cancel();

        final bot = SmartBotController.create(
          playerElo: userStats.eloRating,
          repository: _repository,
          engine: _engine,
          transport: _transport,
          customStepDelay: botTurnDelay,
        );
        _activeBotController = bot;

        final botState = MultiplayerPlayerState(
          playerId: bot.botId,
          nickname: bot.nickname,
          elo: bot.elo,
          lastActionEpochMs: DateTime.now().millisecondsSinceEpoch,
          isBot: true,
        );

        final updatedPlayers = Map<String, MultiplayerPlayerState>.from(_currentRoom!.players);
        updatedPlayers[bot.botId] = botState;

        final playingRoom = _currentRoom!.copyWith(
          status: 'playing',
          matchStartedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
          players: updatedPlayers,
        );

        _currentRoom = playingRoom;
        await _transport.createOrUpdateRoom(playingRoom);
        _startMatchTimer();
        notifyListeners();

        unawaited(bot.runBotTurnLoop(
          roomCode: code,
          target: _targetPerfume!,
        ));
      });
    } catch (e) {
      _isMatchmaking = false;
      _isConnecting = false;
      _matchmakingTicker?.cancel();
      _matchmakingTimer?.cancel();
      _errorMessage = 'Quick match error: $e';
      notifyListeners();
    }
  }

  /// Gracefully cancels the active matchmaking queue.
  Future<void> cancelQuickMatch() async {
    _matchmakingTimer?.cancel();
    _matchmakingTicker?.cancel();
    _isMatchmaking = false;
    _matchmakingElapsedSeconds = 0;

    if (_currentRoom != null && _currentRoom!.status == 'waiting') {
      final code = _currentRoom!.roomCode;
      await leaveRoom();
      await _transport.deleteRoom(code);
    } else {
      notifyListeners();
    }
  }

  // ===========================================================================
  // Subscription & Room Sync
  // ===========================================================================

  Future<void> _subscribeToRoom(String roomCode) async {
    await _roomSubscription?.cancel();

    _roomSubscription = _transport.watchRoom(roomCode).listen(
      (room) {
        if (room == null) {
          _currentRoom = null;
          _stopMatchTimer();
          notifyListeners();
          return;
        }

        final previousStatus = _currentRoom?.status;
        final isNewRound = previousStatus == 'finished' &&
            room.status == 'playing' &&
            (room.matchStartedAtEpochMs != _currentRoom?.matchStartedAtEpochMs ||
                room.targetPerfumeId != _currentRoom?.targetPerfumeId);
        if (isNewRound) {
          _resetLocalBoard();
          _lastProcessedEloDelta = null;
        }

        // Reconcile optimistic local player state if incoming stream event is an older snapshot
        final localMe = _currentRoom?.players[_myPlayerId];
        final incomingMe = room.players[_myPlayerId];
        MultiplayerRoom effectiveRoom = room;

        if (previousStatus == 'finished' && !isNewRound) {
          effectiveRoom = effectiveRoom.copyWith(
            status: 'finished',
            winnerId: _currentRoom?.winnerId ?? effectiveRoom.winnerId,
            winReason: _currentRoom?.winReason ?? effectiveRoom.winReason,
          );
        }

        if (!isNewRound && localMe != null && incomingMe != null) {
          final isLocalAhead = localMe.turnCount > incomingMe.turnCount ||
              (localMe.solved && !incomingMe.solved) ||
              (localMe.exhaustedTurns && !incomingMe.exhaustedTurns);

          if (isLocalAhead) {
            final mergedPlayers = Map<String, MultiplayerPlayerState>.from(room.players);
            mergedPlayers[_myPlayerId] = localMe;
            effectiveRoom = room.copyWith(players: mergedPlayers);
          }
        }

        _currentRoom = effectiveRoom;

        // Ensure target perfume is instantiated
        if (_targetPerfume == null || _targetPerfume!.id != effectiveRoom.targetPerfumeId) {
          _targetPerfume = _repository.getById(effectiveRoom.targetPerfumeId);
          _resetLocalBoard();
        }

        // If matchmaking and a 2nd player joins, cancel queue timers
        if (_isMatchmaking && effectiveRoom.players.length >= 2) {
          _isMatchmaking = false;
          _matchmakingTimer?.cancel();
          _matchmakingTicker?.cancel();
        }

        // When room transitions from waiting to playing, start timer
        if (previousStatus == 'waiting' && effectiveRoom.status == 'playing') {
          _startMatchTimer();
        }

        // When room finishes, handle ELO and cancel timers
        if (effectiveRoom.status == 'finished') {
          _stopMatchTimer();
          _botTimer?.cancel();
          _activeBotController?.stop();
          _handleMatchCompleted(effectiveRoom);
        }

        notifyListeners();
      },
      onError: (dynamic err) {
        _errorMessage = 'Sync error: $err';
        notifyListeners();
      },
    );
  }

  void _startMatchTimer() {
    _matchTimer?.cancel();
    final startedAt = _currentRoom?.matchStartedAtEpochMs ?? DateTime.now().millisecondsSinceEpoch;

    void updateRemaining() {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final elapsedSec = (nowMs - startedAt) ~/ 1000;
      _remainingSeconds = max(0, AppConfig.matchDurationSeconds - elapsedSec);

      if (_remainingSeconds <= 0) {
        _matchTimer?.cancel();
        _handleTimeout();
      }
      notifyListeners();
    }

    updateRemaining();
    _matchTimer = Timer.periodic(const Duration(seconds: 1), (_) => updateRemaining());
  }

  void _stopMatchTimer() {
    _matchTimer?.cancel();
    _matchTimer = null;
  }

  void _resetLocalBoard() {
    _turnEntries.clear();
    _discoveredNotesLower.clear();
    _bonusRevealedNotes.clear();
    _bonusNoteRevealed = false;
  }

  // ===========================================================================
  // Gameplay Actions: Guess, Skip, Hint
  // ===========================================================================

  /// Submits a perfume guess in the active 1v1 duel.
  Future<void> submitGuess(PerfumeModel guess) async {
    if (_currentRoom == null || _currentRoom!.status != 'playing' || _targetPerfume == null) {
      return;
    }

    final me = myState;
    if (me == null || me.solved || me.exhaustedTurns) return;

    final turnNum = _turnEntries.length + 1;
    final entry = _engine.createGuessEntry(
      turnNumber: turnNum,
      guess: guess,
      target: _targetPerfume!,
    );

    final result = entry.guessResult!;

    // Merge shared olfactory notes
    _discoveredNotesLower.addAll(
      result.sharedNotes.map(StringNormalizer.normalizeNoteKey),
    );

    // Record turn entry
    _turnEntries.add(entry);

    // Prepare updated player state
    final nextTurnCount = _turnEntries.length;
    final isSolved = result.isCorrect;
    final isExhausted = nextTurnCount >= 6 && !isSolved;
    final newCloseness = max(me.bestClosenessScore, result.closenessScore);

    final updatedGrid = List<List<String>>.from(me.colorGrid)..add(result.multiplayerColorRow);
    final updatedGuessedIds = List<int>.from(me.guessedPerfumeIds)..add(guess.id);

    final updatedMe = me.copyWith(
      turnCount: nextTurnCount,
      solved: isSolved,
      exhaustedTurns: isExhausted,
      bestClosenessScore: newCloseness,
      colorGrid: updatedGrid,
      guessedPerfumeIds: updatedGuessedIds,
      lastActionEpochMs: DateTime.now().millisecondsSinceEpoch,
    );

    // Check Immediate Victory Condition
    if (isSolved) {
      final updatedPlayers = Map<String, MultiplayerPlayerState>.from(_currentRoom!.players);
      updatedPlayers[_myPlayerId] = updatedMe;

      final finishedRoom = _currentRoom!.copyWith(
        status: 'finished',
        winnerId: _myPlayerId,
        winReason: 'SOLVED_FIRST',
        players: updatedPlayers,
      );
      _currentRoom = finishedRoom;
      _stopMatchTimer();
      await _handleMatchCompleted(finishedRoom);
      await _transport.patchPlayerState(finishedRoom.roomCode, updatedMe);
      await _transport.patchRoomOutcome(
        roomCode: finishedRoom.roomCode,
        status: 'finished',
        winnerId: _myPlayerId,
        winReason: 'SOLVED_FIRST',
      );
      _currentRoom = finishedRoom;
      notifyListeners();
      return;
    }

    // Check Both Exhausted Condition
    final latestRoom = await _transport.fetchRoom(_currentRoom!.roomCode) ?? _currentRoom!;
    final opponent = latestRoom.opponentOf(_myPlayerId);
    if (isExhausted && opponent != null && opponent.exhaustedTurns) {
      final winnerInfo = _resolveExhaustionWinner(updatedMe, opponent);
      final updatedPlayers = Map<String, MultiplayerPlayerState>.from(latestRoom.players);
      updatedPlayers[_myPlayerId] = updatedMe;

      final finishedRoom = latestRoom.copyWith(
        status: 'finished',
        winnerId: winnerInfo.key,
        winReason: winnerInfo.value,
        players: updatedPlayers,
      );
      _currentRoom = finishedRoom;
      _stopMatchTimer();
      await _handleMatchCompleted(finishedRoom);
      await _transport.patchPlayerState(finishedRoom.roomCode, updatedMe);
      await _transport.patchRoomOutcome(
        roomCode: finishedRoom.roomCode,
        status: 'finished',
        winnerId: winnerInfo.key,
        winReason: winnerInfo.value,
      );
      _currentRoom = finishedRoom;
      notifyListeners();
      return;
    }

    // Normal in-game state sync
    final updatedPlayers = Map<String, MultiplayerPlayerState>.from(_currentRoom!.players);
    updatedPlayers[_myPlayerId] = updatedMe;
    _currentRoom = _currentRoom!.copyWith(players: updatedPlayers);
    await _transport.patchPlayerState(_currentRoom!.roomCode, updatedMe);
    notifyListeners();
  }

  /// Skips the active turn to intentionally unlock the next clue tier.
  Future<void> skipTurn() async {
    if (_currentRoom == null || _currentRoom!.status != 'playing' || _targetPerfume == null) {
      return;
    }

    final me = myState;
    if (me == null || me.solved || me.exhaustedTurns) return;

    final turnNum = _turnEntries.length + 1;
    final skipEntry = _engine.createSkipEntry(turnNum);
    _turnEntries.add(skipEntry);

    final nextTurnCount = _turnEntries.length;
    final isExhausted = nextTurnCount >= 6;
    final updatedGrid = List<List<String>>.from(me.colorGrid)
      ..add(['MISS', 'MISS', 'MISS', 'MISS']);

    final updatedMe = me.copyWith(
      turnCount: nextTurnCount,
      exhaustedTurns: isExhausted,
      colorGrid: updatedGrid,
      lastActionEpochMs: DateTime.now().millisecondsSinceEpoch,
    );

    final latestRoom = await _transport.fetchRoom(_currentRoom!.roomCode) ?? _currentRoom!;
    final opponent = latestRoom.opponentOf(_myPlayerId);
    if (isExhausted && opponent != null && opponent.exhaustedTurns) {
      final winnerInfo = _resolveExhaustionWinner(updatedMe, opponent);
      final updatedPlayers = Map<String, MultiplayerPlayerState>.from(latestRoom.players);
      updatedPlayers[_myPlayerId] = updatedMe;

      final finishedRoom = latestRoom.copyWith(
        status: 'finished',
        winnerId: winnerInfo.key,
        winReason: winnerInfo.value,
        players: updatedPlayers,
      );
      _currentRoom = finishedRoom;
      _stopMatchTimer();
      await _handleMatchCompleted(finishedRoom);
      await _transport.createOrUpdateRoom(finishedRoom);
      notifyListeners();
      return;
    }

    final updatedPlayers = Map<String, MultiplayerPlayerState>.from(_currentRoom!.players);
    updatedPlayers[_myPlayerId] = updatedMe;
    _currentRoom = _currentRoom!.copyWith(players: updatedPlayers);
    await _transport.patchPlayerState(_currentRoom!.roomCode, updatedMe);
    notifyListeners();
  }

  /// Reveals a bonus note hint for the local player.
  void useBonusNoteHint() {
    if (_bonusNoteRevealed || _targetPerfume == null) return;
    _bonusNoteRevealed = true;
    final allTargetNotes = _targetPerfume!.notes.allRawNotes;
    for (final note in allTargetNotes) {
      final key = StringNormalizer.normalizeNoteKey(note);
      if (!_discoveredNotesLower.contains(key)) {
        _discoveredNotesLower.add(key);
        _bonusRevealedNotes.add(note);
        break;
      }
    }
    notifyListeners();
  }

  // ===========================================================================
  // Winner Resolution & ELO Calculations
  // ===========================================================================

  MapEntry<String, String> _resolveExhaustionWinner(
    MultiplayerPlayerState p1,
    MultiplayerPlayerState p2,
  ) {
    if (p1.bestClosenessScore > p2.bestClosenessScore) {
      return MapEntry(p1.playerId, 'CLOSEST_AFTER_EXHAUSTION');
    } else if (p2.bestClosenessScore > p1.bestClosenessScore) {
      return MapEntry(p2.playerId, 'CLOSEST_AFTER_EXHAUSTION');
    }
    return const MapEntry('DRAW', 'DRAW');
  }

  Future<void> _handleTimeout() async {
    if (_currentRoom == null || _currentRoom!.status != 'playing') return;

    final me = myState;
    final opp = opponentState;

    String winnerId = 'DRAW';
    String reason = 'CLOSEST_ON_TIMEOUT';

    if (me != null && opp != null) {
      if (me.solved && !opp.solved) {
        winnerId = me.playerId;
        reason = 'SOLVED_FIRST';
      } else if (opp.solved && !me.solved) {
        winnerId = opp.playerId;
        reason = 'SOLVED_FIRST';
      } else if (me.bestClosenessScore > opp.bestClosenessScore) {
        winnerId = me.playerId;
      } else if (opp.bestClosenessScore > me.bestClosenessScore) {
        winnerId = opp.playerId;
      } else {
        winnerId = 'DRAW';
        reason = 'DRAW';
      }
    }

    final finished = _currentRoom!.copyWith(
      status: 'finished',
      winnerId: winnerId,
      winReason: reason,
    );
    _currentRoom = finished;

    await _transport.patchRoomOutcome(
      roomCode: _currentRoom!.roomCode,
      status: 'finished',
      winnerId: winnerId,
      winReason: reason,
    );
  }

  Future<void> _handleMatchCompleted(MultiplayerRoom room) async {
    if (_lastProcessedEloDelta != null) return; // Already processed

    final opp = room.opponentOf(_myPlayerId);
    final myCurrentElo = _storage.getUserStats().eloRating;
    final oppElo = opp?.elo ?? 1000;

    final double outcome;
    if (room.winnerId == _myPlayerId) {
      outcome = 1.0;
    } else if (room.winnerId == 'DRAW') {
      outcome = 0.5;
    } else {
      outcome = 0.0;
    }

    final delta = RankService.calculateEloDelta(
      myElo: myCurrentElo,
      opponentElo: oppElo,
      outcome: outcome,
    );

    _lastProcessedEloDelta = delta;

    // Persist new rating
    final stats = _storage.getUserStats();
    stats.eloRating = max(100, stats.eloRating + delta);
    await _storage.saveUserStats(stats);

    // If won, unlock in cabinet
    if (outcome == 1.0 && room.targetPerfumeId > 0) {
      await _storage.unlockPerfumeInCabinet(
        room.targetPerfumeId,
        mode: 'duel',
      );
    }
  }

  // ===========================================================================
  // Rematch & Teardown
  // ===========================================================================

  /// Requests a rematch with the current opponent in the same room.
  Future<void> requestRematch() async {
    if (_currentRoom == null) return;

    final me = myState;
    if (me == null) return;

    final updatedMe = me.copyWith(wantsRematch: true);
    final updatedPlayers = Map<String, MultiplayerPlayerState>.from(_currentRoom!.players);
    updatedPlayers[_myPlayerId] = updatedMe;
    _currentRoom = _currentRoom!.copyWith(players: updatedPlayers);
    await _transport.patchPlayerState(_currentRoom!.roomCode, updatedMe);
    notifyListeners();

    final opp = opponentState;
    // If opponent also wants rematch, or if host initiates instant round 2 against AI bot
    if (opp != null && (opp.wantsRematch || _activeBotController != null)) {
      await _startRematchRound();
      if (_activeBotController != null && _targetPerfume != null) {
        unawaited(_activeBotController!.runBotTurnLoop(
          roomCode: _currentRoom!.roomCode,
          target: _targetPerfume!,
        ));
      }
    }
  }

  Future<void> _startRematchRound() async {
    final mysteryPool = _repository.mysteryPool;
    final newTarget = mysteryPool[Random().nextInt(mysteryPool.length)];

    final resetPlayers = <String, MultiplayerPlayerState>{};
    for (final entry in _currentRoom!.players.entries) {
      resetPlayers[entry.key] = entry.value.copyWith(
        turnCount: 0,
        solved: false,
        exhaustedTurns: false,
        bestClosenessScore: 0,
        colorGrid: const [],
        guessedPerfumeIds: const [],
        wantsRematch: false,
        lastActionEpochMs: DateTime.now().millisecondsSinceEpoch,
      );
    }

    final rematchRoom = _currentRoom!.copyWith(
      status: 'playing',
      targetPerfumeId: newTarget.id,
      matchStartedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      clearWinner: true,
      players: resetPlayers,
    );

    _lastProcessedEloDelta = null;
    _targetPerfume = newTarget;
    _resetLocalBoard();

    _currentRoom = rematchRoom;
    await _transport.createOrUpdateRoom(rematchRoom);
    _startMatchTimer();
    notifyListeners();
  }

  /// Leaves the current multiplayer duel and cleans up active subscriptions.
  Future<void> leaveRoom() async {
    _stopMatchTimer();
    _botTimer?.cancel();
    _activeBotController?.stop();
    _activeBotController = null;
    _matchmakingTimer?.cancel();
    _matchmakingTicker?.cancel();
    _isMatchmaking = false;
    _matchmakingElapsedSeconds = 0;
    await _roomSubscription?.cancel();
    _roomSubscription = null;

    if (_currentRoom != null) {
      // If host leaving or solitary room, cleanup room node
      if (_currentRoom!.players.length <= 1) {
        await _transport.deleteRoom(_currentRoom!.roomCode);
      }
    }

    _currentRoom = null;
    _targetPerfume = null;
    _resetLocalBoard();
    _lastProcessedEloDelta = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopMatchTimer();
    _botTimer?.cancel();
    _activeBotController?.stop();
    _matchmakingTimer?.cancel();
    _matchmakingTicker?.cancel();
    _roomSubscription?.cancel();
    super.dispose();
  }
}
