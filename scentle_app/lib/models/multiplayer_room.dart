import 'package:flutter/foundation.dart';

/// State of an individual player in an active multiplayer room.
/// Keeps network sync payload compact (~100 bytes) with zero leakage of target perfume name.
@immutable
class MultiplayerPlayerState {
  final String playerId;
  final String nickname;
  final int elo;
  final int turnCount;
  final bool solved;
  final bool exhaustedTurns;
  final int bestClosenessScore;
  final List<List<String>> colorGrid;
  final List<int> guessedPerfumeIds;
  final int lastActionEpochMs;
  final bool wantsRematch;
  final bool isBot;

  const MultiplayerPlayerState({
    required this.playerId,
    required this.nickname,
    required this.elo,
    this.turnCount = 0,
    this.solved = false,
    this.exhaustedTurns = false,
    this.bestClosenessScore = 0,
    this.colorGrid = const [],
    this.guessedPerfumeIds = const [],
    required this.lastActionEpochMs,
    this.wantsRematch = false,
    this.isBot = false,
  });

  MultiplayerPlayerState copyWith({
    String? playerId,
    String? nickname,
    int? elo,
    int? turnCount,
    bool? solved,
    bool? exhaustedTurns,
    int? bestClosenessScore,
    List<List<String>>? colorGrid,
    List<int>? guessedPerfumeIds,
    int? lastActionEpochMs,
    bool? wantsRematch,
    bool? isBot,
  }) {
    return MultiplayerPlayerState(
      playerId: playerId ?? this.playerId,
      nickname: nickname ?? this.nickname,
      elo: elo ?? this.elo,
      turnCount: turnCount ?? this.turnCount,
      solved: solved ?? this.solved,
      exhaustedTurns: exhaustedTurns ?? this.exhaustedTurns,
      bestClosenessScore: bestClosenessScore ?? this.bestClosenessScore,
      colorGrid: colorGrid ?? this.colorGrid,
      guessedPerfumeIds: guessedPerfumeIds ?? this.guessedPerfumeIds,
      lastActionEpochMs: lastActionEpochMs ?? this.lastActionEpochMs,
      wantsRematch: wantsRematch ?? this.wantsRematch,
      isBot: isBot ?? this.isBot,
    );
  }

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'nickname': nickname,
        'elo': elo,
        'turnCount': turnCount,
        'solved': solved,
        'exhaustedTurns': exhaustedTurns,
        'bestClosenessScore': bestClosenessScore,
        'colorGrid': colorGrid,
        'guessedPerfumeIds': guessedPerfumeIds,
        'lastActionEpochMs': lastActionEpochMs,
        'wantsRematch': wantsRematch,
        'isBot': isBot,
      };

  factory MultiplayerPlayerState.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) {
      return MultiplayerPlayerState(
        playerId: '',
        nickname: 'Unknown Nose',
        elo: 1000,
        lastActionEpochMs: 0,
      );
    }

    // Parse 2D color grid safely
    final rawGrid = json['colorGrid'];
    final parsedGrid = <List<String>>[];
    if (rawGrid is List) {
      for (final row in rawGrid) {
        if (row is List) {
          parsedGrid.add(row.map((e) => e.toString()).toList());
        }
      }
    }

    // Parse guessed perfume IDs
    final rawIds = json['guessedPerfumeIds'];
    final parsedIds = <int>[];
    if (rawIds is List) {
      for (final id in rawIds) {
        final parsed = int.tryParse(id.toString());
        if (parsed != null) parsedIds.add(parsed);
      }
    }

    return MultiplayerPlayerState(
      playerId: json['playerId']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? 'Unknown Nose',
      elo: int.tryParse(json['elo']?.toString() ?? '') ?? 1000,
      turnCount: int.tryParse(json['turnCount']?.toString() ?? '') ?? 0,
      solved: json['solved'] == true,
      exhaustedTurns: json['exhaustedTurns'] == true,
      bestClosenessScore: int.tryParse(json['bestClosenessScore']?.toString() ?? '') ?? 0,
      colorGrid: parsedGrid,
      guessedPerfumeIds: parsedIds,
      lastActionEpochMs: int.tryParse(json['lastActionEpochMs']?.toString() ?? '') ?? 0,
      wantsRematch: json['wantsRematch'] == true,
      isBot: json['isBot'] == true,
    );
  }
}

/// Represents a synchronized 1v1 multiplayer game room.
@immutable
class MultiplayerRoom {
  final String roomCode;
  final bool isPublic;
  final String status; // 'waiting', 'playing', 'finished'
  final int targetPerfumeId;
  final int createdAtEpochMs;
  final int? matchStartedAtEpochMs;
  final String? winnerId; // null, 'DRAW', or playerId
  final String? winReason; // 'SOLVED_FIRST', 'CLOSEST_ON_TIMEOUT', 'CLOSEST_AFTER_EXHAUSTION', 'OPPONENT_FORFEIT', 'DRAW'
  final Map<String, MultiplayerPlayerState> players;

  const MultiplayerRoom({
    required this.roomCode,
    this.isPublic = false,
    this.status = 'waiting',
    required this.targetPerfumeId,
    required this.createdAtEpochMs,
    this.matchStartedAtEpochMs,
    this.winnerId,
    this.winReason,
    this.players = const {},
  });

  bool get isWaiting => status == 'waiting';
  bool get isPlaying => status == 'playing';
  bool get isFinished => status == 'finished';
  bool get isFull => players.length >= 2;

  MultiplayerPlayerState? get host =>
      players.isNotEmpty ? players.values.first : null;

  MultiplayerPlayerState? opponentOf(String myPlayerId) {
    for (final entry in players.entries) {
      if (entry.key != myPlayerId) {
        return entry.value;
      }
    }
    return null;
  }

  MultiplayerPlayerState? me(String myPlayerId) => players[myPlayerId];

  MultiplayerRoom copyWith({
    String? roomCode,
    bool? isPublic,
    String? status,
    int? targetPerfumeId,
    int? createdAtEpochMs,
    int? matchStartedAtEpochMs,
    String? winnerId,
    String? winReason,
    bool clearWinner = false,
    Map<String, MultiplayerPlayerState>? players,
  }) {
    return MultiplayerRoom(
      roomCode: roomCode ?? this.roomCode,
      isPublic: isPublic ?? this.isPublic,
      status: status ?? this.status,
      targetPerfumeId: targetPerfumeId ?? this.targetPerfumeId,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      matchStartedAtEpochMs: matchStartedAtEpochMs ?? this.matchStartedAtEpochMs,
      winnerId: clearWinner ? null : (winnerId ?? this.winnerId),
      winReason: clearWinner ? null : (winReason ?? this.winReason),
      players: players ?? this.players,
    );
  }

  Map<String, dynamic> toJson() => {
        'roomCode': roomCode,
        'isPublic': isPublic,
        'status': status,
        'targetPerfumeId': targetPerfumeId,
        'createdAtEpochMs': createdAtEpochMs,
        'matchStartedAtEpochMs': matchStartedAtEpochMs,
        'winnerId': winnerId,
        'winReason': winReason,
        'players': players.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory MultiplayerRoom.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) {
      return MultiplayerRoom(
        roomCode: '',
        targetPerfumeId: 0,
        createdAtEpochMs: 0,
      );
    }

    final parsedPlayers = <String, MultiplayerPlayerState>{};
    final rawPlayers = json['players'];
    if (rawPlayers is Map) {
      rawPlayers.forEach((k, v) {
        if (v is Map) {
          parsedPlayers[k.toString()] = MultiplayerPlayerState.fromJson(v);
        }
      });
    }

    return MultiplayerRoom(
      roomCode: json['roomCode']?.toString().toUpperCase() ?? '',
      isPublic: json['isPublic'] == true,
      status: json['status']?.toString() ?? 'waiting',
      targetPerfumeId: int.tryParse(json['targetPerfumeId']?.toString() ?? '') ?? 0,
      createdAtEpochMs: int.tryParse(json['createdAtEpochMs']?.toString() ?? '') ?? 0,
      matchStartedAtEpochMs: int.tryParse(json['matchStartedAtEpochMs']?.toString() ?? ''),
      winnerId: json['winnerId']?.toString(),
      winReason: json['winReason']?.toString(),
      players: parsedPlayers,
    );
  }
}
