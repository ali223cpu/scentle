import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/utils/platform_env.dart' as platform_env;
import '../core/utils/string_normalizer.dart';
import '../models/perfume_model.dart';

/// Top-level isolate worker function for JSON parsing
List<PerfumeModel> _parsePerfumesIsolate(String rawJson) {
  final dynamic parsed = jsonDecode(rawJson);
  if (parsed is! List) return const [];
  return parsed
      .map((e) => PerfumeModel.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// Singleton repository managing the bundled Scentle database,
/// optimized autocomplete search index, and daily mystery target selection.
class PerfumeRepository {
  static final PerfumeRepository instance = PerfumeRepository._internal();

  PerfumeRepository._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  List<PerfumeModel> _allPerfumes = const [];
  List<PerfumeModel> _mysteryPool = const [];
  Map<int, PerfumeModel> _byId = const {};

  /// All searchable perfumes (12,280), sorted by popularity (votes descending).
  List<PerfumeModel> get allPerfumes => _allPerfumes;

  /// Dedicated mystery target pool (1,229), sorted strictly by ID ascending.
  List<PerfumeModel> get mysteryPool => _mysteryPool;

  /// Total searchable database size.
  int get totalCount => _allPerfumes.length;

  /// Loads and parses scentle_db.json via background isolate.
  Future<void> initialize({
    String assetPath = 'assets/data/scentle_db.json',
    String? rawJson,
  }) async {
    if (_isInitialized) return;

    String jsonContent;
    if (rawJson != null) {
      jsonContent = rawJson;
    } else {
      try {
        jsonContent = await rootBundle.loadString(assetPath);
      } catch (_) {
        // Defensive fallback for headless unit test environments
        final content = await platform_env.readFileAsString(assetPath);
        if (content != null) {
          jsonContent = content;
        } else {
          rethrow;
        }
      }
    }

    // Parse in background isolate to keep UI thread unblocked
    final List<PerfumeModel> loaded = kIsWeb
        ? _parsePerfumesIsolate(jsonContent)
        : await compute(_parsePerfumesIsolate, jsonContent);

    // 1. Sort all perfumes by votes descending for autocomplete relevance
    final sortedByVotes = List<PerfumeModel>.from(loaded)
      ..sort((a, b) => b.votes.compareTo(a.votes));
    _allPerfumes = List.unmodifiable(sortedByVotes);

    // 2. Build mystery pool strictly ordered by ID for deterministic hash mapping
    final mystery = _allPerfumes.where((p) => p.isMysteryEligible).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    _mysteryPool = List.unmodifiable(mystery);

    // 3. Populate O(1) ID lookup hash map
    final map = <int, PerfumeModel>{};
    for (final p in _allPerfumes) {
      map[p.id] = p;
    }
    _byId = Map.unmodifiable(map);

    _isInitialized = true;
  }

  /// Resets repository state (used for testing environments).
  @visibleForTesting
  void resetForTesting() {
    _isInitialized = false;
    _allPerfumes = const [];
    _mysteryPool = const [];
    _byId = const {};
  }

  /// O(1) lookup by Perfume ID.
  PerfumeModel? getById(int id) => _byId[id];

  /// High-performance tokenized autocomplete search.
  /// Runs in <5ms across 12,280 records.
  List<PerfumeModel> search(
    String query, {
    Set<int>? excludeIds,
    int limit = 12,
  }) {
    final normalized = StringNormalizer.normalizeForSearch(query);
    if (normalized.isEmpty) return const [];

    final tokens =
        normalized.split(' ').where((t) => t.isNotEmpty).toList(growable: false);
    if (tokens.isEmpty) return const [];

    final tokenCount = tokens.length;
    final firstToken = tokens[0];

    final bucketA = <PerfumeModel>[];
    final bucketB = <PerfumeModel>[];

    // Fast-path unrolled token matching across 12,280 items
    if (tokenCount == 1) {
      for (final perfume in _allPerfumes) {
        if (excludeIds != null && excludeIds.contains(perfume.id)) continue;
        if (perfume.searchKey.contains(firstToken)) {
          if (perfume.normalizedName.startsWith(firstToken) ||
              perfume.normalizedBrand.startsWith(firstToken)) {
            bucketA.add(perfume);
            if (bucketA.length >= limit) return bucketA;
          } else {
            bucketB.add(perfume);
          }
        }
      }
    } else if (tokenCount == 2) {
      final secondToken = tokens[1];
      for (final perfume in _allPerfumes) {
        if (excludeIds != null && excludeIds.contains(perfume.id)) continue;
        if (perfume.searchKey.contains(firstToken) &&
            perfume.searchKey.contains(secondToken)) {
          if (perfume.normalizedName.startsWith(firstToken) ||
              perfume.normalizedBrand.startsWith(firstToken)) {
            bucketA.add(perfume);
            if (bucketA.length >= limit) return bucketA;
          } else {
            bucketB.add(perfume);
          }
        }
      }
    } else {
      for (final perfume in _allPerfumes) {
        if (excludeIds != null && excludeIds.contains(perfume.id)) continue;
        bool matches = true;
        for (int i = 0; i < tokenCount; i++) {
          if (!perfume.searchKey.contains(tokens[i])) {
            matches = false;
            break;
          }
        }
        if (matches) {
          if (perfume.normalizedName.startsWith(firstToken) ||
              perfume.normalizedBrand.startsWith(firstToken)) {
            bucketA.add(perfume);
            if (bucketA.length >= limit) return bucketA;
          } else {
            bucketB.add(perfume);
          }
        }
      }
    }

    if (bucketA.length >= limit) {
      return bucketA.take(limit).toList();
    }

    final needed = limit - bucketA.length;
    return [...bucketA, ...bucketB.take(needed)];
  }

  /// Returns the continuous daily puzzle number since Day 1 (2026-01-01 UTC).
  int getDailyPuzzleNumber(DateTime utcDate) {
    final dateOnly = DateTime.utc(utcDate.year, utcDate.month, utcDate.day);
    final epoch = DateTime.utc(2026, 1, 1);
    final diffDays = dateOnly.difference(epoch).inDays + 1;
    return diffDays < 1 ? 1 : diffDays;
  }

  /// Cryptographically deterministic UTC daily puzzle selector.
  /// Generates the exact same mystery perfume for every player worldwide on a given date.
  PerfumeModel getDailyTarget(DateTime utcDate) {
    if (_mysteryPool.isEmpty) {
      throw StateError('Cannot pick daily target before repository initialization');
    }

    final yearStr = utcDate.year.toString().padLeft(4, '0');
    final monthStr = utcDate.month.toString().padLeft(2, '0');
    final dayStr = utcDate.day.toString().padLeft(2, '0');
    final dateStr = '$yearStr-$monthStr-$dayStr';

    final digest = sha256.convert(utf8.encode('SCENTLE_DAILY_MYSTERY_v1_$dateStr'));
    final hex8 = digest.toString().substring(0, 8);
    final hashInt = int.parse(hex8, radix: 16);

    final index = hashInt % _mysteryPool.length;
    return _mysteryPool[index];
  }

  /// Selects a random target from the mystery pool for practice/multiplayer modes.
  PerfumeModel getRandomMysteryTarget({
    Set<int>? excludeIds,
    Random? random,
  }) {
    if (_mysteryPool.isEmpty) {
      throw StateError('Mystery pool is empty; initialize repository first');
    }

    List<PerfumeModel> pool = _mysteryPool;
    if (excludeIds != null && excludeIds.isNotEmpty) {
      final filtered = _mysteryPool.where((p) => !excludeIds.contains(p.id)).toList();
      if (filtered.isNotEmpty) {
        pool = filtered;
      }
    }

    final rng = random ?? Random();
    return pool[rng.nextInt(pool.length)];
  }
}
