import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import '../models/multiplayer_room.dart';

/// Abstract transport contract for real-time 1v1 multiplayer synchronization.
abstract class MultiplayerTransport {
  Future<void> createOrUpdateRoom(MultiplayerRoom room);
  Future<MultiplayerRoom?> fetchRoom(String roomCode);
  Stream<MultiplayerRoom?> watchRoom(String roomCode);
  Future<void> patchPlayerState(String roomCode, MultiplayerPlayerState playerState);
  Future<void> patchRoomOutcome({
    required String roomCode,
    required String status,
    required String? winnerId,
    required String? winReason,
  });
  Future<void> deleteRoom(String roomCode);
  Future<List<MultiplayerRoom>> findOpenPublicRooms();
  Future<void> dispose();

  /// Factory providing either Firebase REST/SSE or Local Loopback based on configuration.
  static MultiplayerTransport createDefault({MultiplayerTransport? override}) {
    if (override != null) return override;

    final dbUrl = AppConfig.firebaseRealtimeDbUrl.trim();
    if (dbUrl.isNotEmpty && dbUrl.startsWith('http')) {
      return FirebaseRestSseTransport(baseUrl: dbUrl);
    }
    return LocalLoopbackTransport.shared;
  }
}

/// In-memory broadcast transport for local device testing, simulated opponents,
/// and automated unit tests requiring $0 server configuration.
class LocalLoopbackTransport implements MultiplayerTransport {
  static final LocalLoopbackTransport shared = LocalLoopbackTransport._();

  LocalLoopbackTransport._() : _rooms = <String, MultiplayerRoom>{};

  /// Creates an isolated instance (useful for independent tests).
  factory LocalLoopbackTransport.isolated() => LocalLoopbackTransport._custom(
        rooms: <String, MultiplayerRoom>{},
      );

  LocalLoopbackTransport._custom({required Map<String, MultiplayerRoom> rooms})
      : _rooms = rooms;

  final Map<String, MultiplayerRoom> _rooms;
  final Map<String, StreamController<MultiplayerRoom?>> _controllers = {};

  StreamController<MultiplayerRoom?> _getController(String code) {
    return _controllers.putIfAbsent(
      code.toUpperCase(),
      () => StreamController<MultiplayerRoom?>.broadcast(),
    );
  }

  @override
  Future<void> createOrUpdateRoom(MultiplayerRoom room) async {
    final code = room.roomCode.toUpperCase();
    _rooms[code] = room;
    _getController(code).add(room);
  }

  @override
  Future<MultiplayerRoom?> fetchRoom(String roomCode) async {
    return _rooms[roomCode.toUpperCase()];
  }

  @override
  Stream<MultiplayerRoom?> watchRoom(String roomCode) {
    final code = roomCode.toUpperCase();
    final controller = _getController(code);

    // Yield current snapshot immediately on subscription
    return Stream<MultiplayerRoom?>.multi((emitter) {
      if (_rooms.containsKey(code)) {
        emitter.add(_rooms[code]);
      }
      final sub = controller.stream.listen(
        emitter.add,
        onError: emitter.addError,
        onDone: emitter.close,
      );
      emitter.onCancel = () => sub.cancel();
    });
  }

  @override
  Future<void> patchPlayerState(
    String roomCode,
    MultiplayerPlayerState playerState,
  ) async {
    final code = roomCode.toUpperCase();
    final current = _rooms[code];
    if (current == null) return;

    final updatedPlayers = Map<String, MultiplayerPlayerState>.from(current.players);
    updatedPlayers[playerState.playerId] = playerState;

    final updatedRoom = current.copyWith(
      players: updatedPlayers,
      status: playerState.solved ? 'finished' : current.status,
      winnerId: playerState.solved ? playerState.playerId : current.winnerId,
      winReason: playerState.solved ? 'SOLVED_FIRST' : current.winReason,
    );
    _rooms[code] = updatedRoom;
    _getController(code).add(updatedRoom);
  }

  @override
  Future<void> patchRoomOutcome({
    required String roomCode,
    required String status,
    required String? winnerId,
    required String? winReason,
  }) async {
    final code = roomCode.toUpperCase();
    final current = _rooms[code];
    if (current == null) return;

    final updatedRoom = current.copyWith(
      status: status,
      winnerId: winnerId,
      winReason: winReason,
    );
    _rooms[code] = updatedRoom;
    _getController(code).add(updatedRoom);
  }

  @override
  Future<void> deleteRoom(String roomCode) async {
    final code = roomCode.toUpperCase();
    _rooms.remove(code);
    if (_controllers.containsKey(code)) {
      _controllers[code]?.add(null);
      await _controllers[code]?.close();
      _controllers.remove(code);
    }
  }

  @override
  Future<List<MultiplayerRoom>> findOpenPublicRooms() async {
    return _rooms.values
        .where((r) => r.isPublic && r.isWaiting && !r.isFull)
        .toList();
  }

  /// Clears in-memory state between tests.
  void reset() {
    _rooms.clear();
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }

  @override
  Future<void> dispose() async {
    reset();
  }
}

/// Firebase Realtime Database transport utilizing standard HTTP REST and Server-Sent Events (SSE).
/// Operates on all Flutter platforms with ZERO native Google Services gradle/cocoapods plugins.
class FirebaseRestSseTransport implements MultiplayerTransport {
  final String baseUrl;
  final http.Client _client;

  FirebaseRestSseTransport({
    required String baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client();

  Uri _roomUri(String roomCode) =>
      Uri.parse('$baseUrl/rooms/${roomCode.toUpperCase()}.json');

  @override
  Future<void> createOrUpdateRoom(MultiplayerRoom room) async {
    final uri = _roomUri(room.roomCode);
    final payload = jsonEncode(room.toJson());
    final response = await _client.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: payload,
    );
    if (response.statusCode >= 400) {
      throw HttpException('Failed to update room: ${response.statusCode} - ${response.body}');
    }
  }

  @override
  Future<MultiplayerRoom?> fetchRoom(String roomCode) async {
    final uri = _roomUri(roomCode);
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == 'null') return null;
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return MultiplayerRoom.fromJson(decoded);
      }
    }
    return null;
  }

  @override
  Future<void> patchPlayerState(
    String roomCode,
    MultiplayerPlayerState playerState,
  ) async {
    final cleanCode = roomCode.trim().toUpperCase();
    final uri = Uri.parse(
      '$baseUrl/rooms/$cleanCode/players/${playerState.playerId}.json',
    );
    // Surgical PATCH updates ONLY this player's node—never overwrites opponent's concurrent guess
    final response = await _client
        .patch(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(playerState.toJson()),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode >= 400) {
      throw HttpException('Failed to patch player state: HTTP ${response.statusCode} - ${response.body}');
    }
  }

  /// Atomic status/winner resolution without touching the players map
  @override
  Future<void> patchRoomOutcome({
    required String roomCode,
    required String status,
    required String? winnerId,
    required String? winReason,
  }) async {
    final cleanCode = roomCode.trim().toUpperCase();
    final uri = Uri.parse('$baseUrl/rooms/$cleanCode.json');
    final response = await _client
        .patch(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'status': status,
            'winnerId': winnerId,
            'winReason': winReason,
          }),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode >= 400) {
      throw HttpException('Failed to patch room outcome: HTTP ${response.statusCode} - ${response.body}');
    }
  }

  @override
  Future<void> deleteRoom(String roomCode) async {
    final uri = _roomUri(roomCode);
    await _client.delete(uri);
  }

  @override
  Future<List<MultiplayerRoom>> findOpenPublicRooms() async {
    final uri = Uri.parse('$baseUrl/rooms.json');
    final response = await _client.get(uri);
    if (response.statusCode == 200 && response.body != 'null') {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final list = <MultiplayerRoom>[];
        decoded.forEach((key, value) {
          if (value is Map) {
            final room = MultiplayerRoom.fromJson(value);
            if (room.isPublic && room.isWaiting && !room.isFull) {
              list.add(room);
            }
          }
        });
        return list;
      }
    }
    return [];
  }

  @override
  Stream<MultiplayerRoom?> watchRoom(String roomCode) {
    late StreamController<MultiplayerRoom?> controller;
    http.Client? streamClient;
    Timer? pollTimer;
    bool isCancelled = false;

    Future<void> pushSnapshot() async {
      try {
        final room = await fetchRoom(roomCode);
        if (!isCancelled && !controller.isClosed) {
          controller.add(room);
        }
      } catch (e) {
        if (!isCancelled && !controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    controller = StreamController<MultiplayerRoom?>.broadcast(
      onListen: () async {
        // Immediate initial snapshot
        await pushSnapshot();

        // Attempt SSE connection with automatic REST polling fallback
        try {
          streamClient = http.Client();
          final request = http.Request('GET', _roomUri(roomCode));
          request.headers['Accept'] = 'text/event-stream';

          final streamedResponse = await streamClient!.send(request);
          if (streamedResponse.statusCode == 200) {
            streamedResponse.stream
                .transform(utf8.decoder)
                .transform(const LineSplitter())
                .listen(
              (line) {
                if (isCancelled || controller.isClosed) return;
                if (line.startsWith('data:')) {
                  final rawData = line.substring(5).trim();
                  if (rawData == 'null') {
                    controller.add(null);
                  } else if (rawData.isNotEmpty) {
                    try {
                      final dynamic parsed = jsonDecode(rawData);
                      if (parsed is Map) {
                        if (parsed.containsKey('data')) {
                          final innerData = parsed['data'];
                          if (innerData is Map) {
                            controller.add(MultiplayerRoom.fromJson(innerData));
                          } else if (innerData == null) {
                            controller.add(null);
                          } else {
                            // Sub-path mutation, fetch fresh full snapshot
                            pushSnapshot();
                          }
                        } else {
                          controller.add(MultiplayerRoom.fromJson(parsed));
                        }
                      }
                    } catch (_) {
                      pushSnapshot();
                    }
                  }
                }
              },
              onError: (dynamic err) {
                // On stream failure, fallback to short polling
                pollTimer?.cancel();
                pollTimer = Timer.periodic(
                  const Duration(seconds: 2),
                  (_) => pushSnapshot(),
                );
              },
              onDone: () {
                if (!isCancelled) {
                  pollTimer = Timer.periodic(
                    const Duration(seconds: 2),
                    (_) => pushSnapshot(),
                  );
                }
              },
            );
          } else {
            // Server did not accept event-stream, fall back to polling
            pollTimer = Timer.periodic(
              const Duration(seconds: 2),
              (_) => pushSnapshot(),
            );
          }
        } catch (_) {
          pollTimer = Timer.periodic(
            const Duration(seconds: 2),
            (_) => pushSnapshot(),
          );
        }
      },
      onCancel: () {
        isCancelled = true;
        pollTimer?.cancel();
        streamClient?.close();
      },
    );

    return controller.stream;
  }

  @override
  Future<void> dispose() async {
    _client.close();
  }
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);

  @override
  String toString() => 'HttpException: $message';
}
