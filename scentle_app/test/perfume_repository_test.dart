import 'package:flutter_test/flutter_test.dart';
import 'package:scentle_app/core/utils/string_normalizer.dart';
import 'package:scentle_app/services/perfume_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await PerfumeRepository.instance.initialize();
  });

  group('PerfumeRepository Dataset & Model Invariants', () {
    test('1. Database contains exactly 12,280 searchable perfumes and 1,229 Tier 2 mystery targets', () {
      final repo = PerfumeRepository.instance;
      expect(repo.allPerfumes.length, 12280);
      expect(repo.mysteryPool.length, 1229);
      expect(repo.totalCount, 12280);
    });

    test('2. Every perfume in mysteryPool has non-empty top, middle, base notes and >= 3 accords', () {
      final repo = PerfumeRepository.instance;
      for (final perfume in repo.mysteryPool) {
        expect(
          perfume.notes.top.isNotEmpty,
          isTrue,
          reason: 'Perfume ${perfume.id} (${perfume.displayTitle}) missing top notes',
        );
        expect(
          perfume.notes.middle.isNotEmpty,
          isTrue,
          reason: 'Perfume ${perfume.id} (${perfume.displayTitle}) missing middle notes',
        );
        expect(
          perfume.notes.base.isNotEmpty,
          isTrue,
          reason: 'Perfume ${perfume.id} (${perfume.displayTitle}) missing base notes',
        );
        expect(
          perfume.accords.length >= 3,
          isTrue,
          reason: 'Perfume ${perfume.id} (${perfume.displayTitle}) has fewer than 3 accords',
        );
        expect(perfume.year, greaterThan(1800));
        expect(perfume.brand.trim().isNotEmpty, isTrue);
      }
    });

    test('3. getById(151345) returns Sauvage Dior with correct flankerLineId, decade, and normalized note display', () {
      final repo = PerfumeRepository.instance;
      final sauvage = repo.getById(151345);

      expect(sauvage, isNotNull);
      expect(sauvage!.name, 'Sauvage');
      expect(sauvage.brand, 'Dior');
      expect(sauvage.country, 'France');
      expect(sauvage.year, 2015);
      expect(sauvage.gender, 'Men');
      expect(sauvage.flankerLineId, anyOf(equals('766b96'), equals('7d7bd6')));
      expect(sauvage.releaseDecade, '2010s');
      expect(sauvage.isMysteryEligible, isTrue);

      // Verify note display mapping Title Casing
      expect(sauvage.normalizedToDisplayNote['elemi'], 'Elemi');
      expect(sauvage.normalizedToDisplayNote['calabrian bergamot'], 'Calabrian Bergamot');
      expect(sauvage.normalizedNotesSet.contains('ambroxan'), isTrue);
    });

    test('4. search("dior sauvage") returns Sauvage (151345) as #1 result in under 15ms', () {
      final repo = PerfumeRepository.instance;
      // Warm up search JIT execution path
      repo.search('warmup test query');

      final stopwatch = Stopwatch()..start();
      final results = repo.search('dior sauvage');
      stopwatch.stop();

      expect(results.isNotEmpty, isTrue);
      expect(results.first.id, 151345);
      expect(results.first.name, 'Sauvage');
      expect(results.first.brand, 'Dior');
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(15),
        reason: 'Search took ${stopwatch.elapsedMilliseconds}ms, expected < 15ms',
      );
    });

    test('5. search("francois demachy") matches perfumes by François Demachy with diacritic normalization', () {
      final repo = PerfumeRepository.instance;
      final results = repo.search('francois demachy');

      expect(results.isNotEmpty, isTrue);
      for (final p in results) {
        final normPerfumer = StringNormalizer.normalizeForSearch(p.perfumer);
        expect(normPerfumer.contains('francois demachy'), isTrue);
      }
    });

    test('6. search("sauvage", excludeIds: {151345}) excludes ID 151345 and returns flankers', () {
      final repo = PerfumeRepository.instance;
      final results = repo.search('sauvage', excludeIds: {151345});

      expect(results.isNotEmpty, isTrue);
      expect(results.any((p) => p.id == 151345), isFalse);

      final resultNames = results.map((p) => p.name).toList();
      expect(resultNames.contains('Sauvage Elixir'), isTrue);
      expect(resultNames.contains('Sauvage Eau de Parfum'), isTrue);
    });

    test('7. getDailyTarget(DateTime.utc(2026, 10, 18)) is deterministic across multiple calls', () {
      final repo = PerfumeRepository.instance;
      final date = DateTime.utc(2026, 10, 18);

      final target1 = repo.getDailyTarget(date);
      final target2 = repo.getDailyTarget(date);
      final target3 = repo.getDailyTarget(date);

      expect(target1.id, target2.id);
      expect(target2.id, target3.id);
      expect(target1.isMysteryEligible, isTrue);

      final puzzleNumber = repo.getDailyPuzzleNumber(date);
      expect(puzzleNumber, greaterThan(1));
    });

    test('8. Fisher-Yates schedule guarantees 1,229 unique daily targets with 0 repeats for 1,229 days', () {
      final repo = PerfumeRepository.instance;
      final seenIds = <int>{};
      final startDate = DateTime.utc(2026, 1, 1);

      for (int day = 0; day < 1229; day++) {
        final date = startDate.add(Duration(days: day));
        final target = repo.getDailyTarget(date);
        expect(seenIds.contains(target.id), isFalse, reason: 'Duplicate on day $day: ${target.name}');
        seenIds.add(target.id);
      }
      expect(seenIds.length, 1229);
    });
  });

  group('StringNormalizer Unit Tests', () {
    test('Diacritic stripping and punctuation handling', () {
      expect(StringNormalizer.normalizeForSearch('François Demachy'), 'francois demachy');
      expect(StringNormalizer.normalizeForSearch("L'Eau d'Issey"), 'leau dissey');
      expect(StringNormalizer.normalizeForSearch('Chloé - Nomade'), 'chloe nomade');
      expect(StringNormalizer.normalizeForSearch('Lancôme & Hermès'), 'lancome hermes');
    });

    test('Note display title casing', () {
      expect(StringNormalizer.formatNoteDisplay('elemi'), 'Elemi');
      expect(StringNormalizer.formatNoteDisplay('calabrian bergamot'), 'Calabrian Bergamot');
      expect(StringNormalizer.formatNoteDisplay('pink pepper'), 'Pink Pepper');
    });
  });
}
