import '../core/utils/string_normalizer.dart';

/// Olfactory pyramid model holding top, middle, and base notes.
class NotePyramid {
  final List<String> top;
  final List<String> middle;
  final List<String> base;

  const NotePyramid({
    required this.top,
    required this.middle,
    required this.base,
  });

  factory NotePyramid.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const NotePyramid(top: [], middle: [], base: []);
    }

    final t = (json['t'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];

    final m = (json['m'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];

    final b = (json['b'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];

    final l = (json['l'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];

    // If linear fragrance and top/mid/base are empty, assign to middle notes
    if (m.isEmpty && t.isEmpty && b.isEmpty && l.isNotEmpty) {
      return NotePyramid(top: t, middle: l, base: b);
    }

    return NotePyramid(top: t, middle: m, base: b);
  }

  Map<String, dynamic> toJson() => {
        't': top,
        'm': middle,
        'b': base,
      };

  /// UI-friendly Title Case formatted notes.
  List<String> get topDisplay =>
      top.map(StringNormalizer.formatNoteDisplay).toList();

  List<String> get middleDisplay =>
      middle.map(StringNormalizer.formatNoteDisplay).toList();

  List<String> get baseDisplay =>
      base.map(StringNormalizer.formatNoteDisplay).toList();

  /// All notes combined in pyramid order.
  List<String> get allRawNotes => [...top, ...middle, ...base];
}

/// Strongly-typed immutable model representing a perfume in Scentle.
class PerfumeModel {
  final int id;
  final String name;
  final String brand;
  final String country;
  final int year;
  final String gender;
  final String perfumer;
  final String imageUrl;
  final int votes;
  final String flankerLineId;
  final NotePyramid notes;
  final List<String> accords;
  final bool isMysteryEligible;

  // Precomputed cached fields for <5ms autocomplete and O(1) clue evaluation
  late final String displayTitle;
  late final String searchKey;
  late final String normalizedName;
  late final String normalizedBrand;
  late final Set<String> normalizedNotesSet;
  late final Map<String, String> normalizedToDisplayNote;

  PerfumeModel({
    required this.id,
    required this.name,
    required this.brand,
    this.country = 'Unknown',
    this.year = 0,
    this.gender = 'Unisex',
    this.perfumer = 'Unknown',
    this.imageUrl = '',
    this.votes = 0,
    this.flankerLineId = '',
    required this.notes,
    this.accords = const [],
    this.isMysteryEligible = false,
  }) {
    _initComputed();
  }

  factory PerfumeModel.fromJson(Map<String, dynamic> json) {
    final rawBrand = json['b']?.toString() ?? '';
    final rawName = json['n']?.toString() ?? '';
    final rawCountry = json['c']?.toString() ?? '';
    final rawPerfumer = json['p']?.toString() ?? '';

    return PerfumeModel(
      id: json['id'] as int? ?? 0,
      name: rawName,
      brand: rawBrand,
      country: rawCountry.trim().isEmpty ? 'Unknown' : rawCountry.trim(),
      year: json['y'] as int? ?? 0,
      gender: (json['g']?.toString().trim().isEmpty ?? true)
          ? 'Unisex'
          : json['g'].toString().trim(),
      perfumer: rawPerfumer.trim().isEmpty ? 'Unknown' : rawPerfumer.trim(),
      imageUrl: json['img']?.toString() ?? '',
      votes: json['v'] as int? ?? 0,
      flankerLineId: json['fl']?.toString() ?? '',
      notes: NotePyramid.fromJson(json['nt'] as Map<String, dynamic>?),
      accords: (json['ac'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const <String>[],
      isMysteryEligible: json['m'] == 1,
    );
  }

  void _initComputed() {
    displayTitle = '$brand — $name';
    normalizedName = StringNormalizer.normalizeForSearch(name);
    normalizedBrand = StringNormalizer.normalizeForSearch(brand);
    searchKey = StringNormalizer.normalizeForSearch(
        '$brand $name $year $perfumer $country');

    final noteSet = <String>{};
    final noteMap = <String, String>{};
    for (final raw in notes.allRawNotes) {
      final key = StringNormalizer.normalizeNoteKey(raw);
      if (key.isNotEmpty) {
        noteSet.add(key);
        noteMap.putIfAbsent(key, () => StringNormalizer.formatNoteDisplay(raw));
      }
    }
    normalizedNotesSet = noteSet;
    normalizedToDisplayNote = noteMap;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'n': name,
        'b': brand,
        'c': country,
        'y': year,
        'g': gender,
        'p': perfumer,
        'img': imageUrl,
        'v': votes,
        'fl': flankerLineId,
        'nt': notes.toJson(),
        'ac': accords,
        if (isMysteryEligible) 'm': 1,
      };

  /// Decadal grouping helper for Wordle clue evaluation.
  String get releaseDecade => year > 0 ? '${(year ~/ 10) * 10}s' : 'Unknown';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PerfumeModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PerfumeModel(id: $id, title: $displayTitle, v: $votes)';
}
