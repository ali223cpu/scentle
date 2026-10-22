import 'package:flutter/material.dart';
import '../core/theme/scentle_theme.dart';
import '../models/cabinet_entry.dart';
import '../models/perfume_model.dart';
import '../services/perfume_repository.dart';
import '../services/storage_service.dart';
import '../widgets/bottle_detail_modal.dart';
import '../widgets/bottle_image_widget.dart';

/// Luxury showcase screen displaying the player's unlocked fragrance flacons,
/// collection progress toward 1,229 iconic targets, and filtering tools.
class CabinetScreen extends StatefulWidget {
  final StorageService? storage;
  final PerfumeRepository? repository;

  const CabinetScreen({
    super.key,
    this.storage,
    this.repository,
  });

  @override
  State<CabinetScreen> createState() => _CabinetScreenState();
}

class _CabinetScreenState extends State<CabinetScreen> {
  late final StorageService _storage;
  late final PerfumeRepository _repository;
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'All'; // 'All', 'Daily Wins', '1v1 Trophies', 'Atelier'
  String _searchQuery = '';

  static const int _totalMysteryPoolSize = 1229;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? StorageService.instance;
    _repository = widget.repository ?? PerfumeRepository.instance;
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CabinetEntry> _getFilteredEntries(List<CabinetEntry> all) {
    return all.where((entry) {
      final perfume = entry.perfume;
      if (perfume == null) return false;

      // 1. Mode Category Filter
      final modeLower = entry.mode.toLowerCase();
      if (_selectedFilter == 'Daily Wins' && modeLower != 'daily') {
        return false;
      } else if (_selectedFilter == '1v1 Trophies' && modeLower != 'duel') {
        return false;
      } else if (_selectedFilter == 'Atelier' && (modeLower != 'unlimited' && modeLower != 'atelier')) {
        return false;
      }

      // 2. Search Query Filter (Brand, Name, Accords)
      if (_searchQuery.isNotEmpty) {
        final nameMatch = perfume.name.toLowerCase().contains(_searchQuery);
        final brandMatch = perfume.brand.toLowerCase().contains(_searchQuery);
        final accordMatch = perfume.accords.any((a) => a.toLowerCase().contains(_searchQuery));
        if (!nameMatch && !brandMatch && !accordMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = _storage.getUnlockedCabinetEntries(repository: _repository);
    final filteredEntries = _getFilteredEntries(allEntries);
    final unlockedCount = allEntries.length;
    final progressFraction = (unlockedCount / _totalMysteryPoolSize).clamp(0.0, 1.0);
    final sc = context.sc;

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 640 ? 3 : 2;

    return Scaffold(
      backgroundColor: sc.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'MY SCENT CABINET',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: sc.primaryText,
          ),
        ),
        centerTitle: true,
        backgroundColor: sc.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: sc.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Progress Header & Metrics Case
            _buildProgressHeader(sc, unlockedCount, progressFraction),

            // 2. Filter Strip & Search Bar
            _buildFilterAndSearchBar(sc),

            // 3. Grid of Flacon Trophies or Empty State
            Expanded(
              child: allEntries.isEmpty
                  ? _buildGlobalEmptyState(sc)
                  : filteredEntries.isEmpty
                      ? _buildFilterEmptyState(sc)
                      : _buildTrophyGrid(sc, filteredEntries, crossAxisCount),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader(
    ScentleThemeColors sc,
    int unlockedCount,
    double progressFraction,
  ) {
    final percentage = (progressFraction * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: sc.surfaceSecondary,
        border: Border(bottom: BorderSide(color: sc.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Collected: $unlockedCount / $_totalMysteryPoolSize Iconic Flacons',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: sc.primaryText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sc.accentBadgeFill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sc.accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: sc.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressFraction,
              minHeight: 7,
              backgroundColor: sc.border,
              valueColor: AlwaysStoppedAnimation<Color>(sc.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearchBar(ScentleThemeColors sc) {
    final filters = ['All', 'Daily Wins', '1v1 Trophies', 'Atelier'];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: sc.scaffoldBg,
      child: Column(
        children: [
          // Search Input
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: sc.cardSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sc.border),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 13, color: sc.primaryText),
              decoration: InputDecoration(
                hintText: 'Search cabinet by brand, name, or accord...',
                hintStyle: TextStyle(fontSize: 12, color: sc.mutedText),
                prefixIcon: Icon(Icons.search, size: 18, color: sc.mutedText),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 16, color: sc.mutedText),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((label) {
                final isSelected = _selectedFilter == label;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = label);
                      }
                    },
                    selectedColor: sc.ctaBackground,
                    backgroundColor: sc.cardSurface,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? sc.ctaForeground : sc.primaryText,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? sc.ctaBackground : sc.border,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrophyGrid(
    ScentleThemeColors sc,
    List<CabinetEntry> entries,
    int crossAxisCount,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.70,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final perfume = entry.perfume!;
        return _buildFlaconCard(context, sc, entry, perfume);
      },
    );
  }

  Widget _buildFlaconCard(
    BuildContext context,
    ScentleThemeColors sc,
    CabinetEntry entry,
    PerfumeModel perfume,
  ) {
    final primaryAccord = perfume.accords.isNotEmpty ? perfume.accords.first : 'Signature';

    return InkWell(
      onTap: () => BottleDetailModal.show(context, perfume: perfume, entry: entry),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: sc.cardSurface, // Pure Studio White container
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sc.border),
          boxShadow: [
            BoxShadow(
              color: sc.cardShadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getModeBadgeColor(sc, entry.mode).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _getModeBadgeColor(sc, entry.mode).withValues(alpha: 0.6),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    entry.mode.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: _getModeBadgeColor(sc, entry.mode),
                    ),
                  ),
                ),
                Text(
                  perfume.year > 0 ? '${perfume.year}' : '',
                  style: TextStyle(fontSize: 10, color: sc.mutedText),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // High-Res Studio Flacon
            Expanded(
              child: Center(
                child: BottleImageWidget(
                  perfume: perfume,
                  blurSigma: 0.0,
                  height: 110,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Brand
            Text(
              perfume.brand.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: sc.accent,
              ),
            ),
            const SizedBox(height: 2),

            // Perfume Name
            Text(
              perfume.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: sc.primaryText,
              ),
            ),
            const SizedBox(height: 4),

            // Primary Accord Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: sc.surfaceSecondary,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: sc.border, width: 0.8),
              ),
              child: Text(
                primaryAccord.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: sc.primaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getModeBadgeColor(ScentleThemeColors sc, String mode) {
    switch (mode.toLowerCase()) {
      case 'daily':
        return sc.accent;
      case 'duel':
        return sc.closeMatch;
      case 'unlimited':
      case 'atelier':
      default:
        return sc.exactMatch;
    }
  }

  Widget _buildGlobalEmptyState(ScentleThemeColors sc) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: sc.surfaceSecondary,
                shape: BoxShape.circle,
                border: Border.all(color: sc.accent.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Icon(
                Icons.account_balance_outlined,
                size: 48,
                color: sc.accent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'YOUR CABINET AWAITS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                color: sc.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Solve your first Daily Scentle or 1v1 Duel to place your first bottle in the cabinet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: sc.mutedText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.play_arrow, size: 18, color: sc.ctaForeground),
              label: Text(
                'START TODAY\'S SCENTLE',
                style: TextStyle(fontWeight: FontWeight.bold, color: sc.ctaForeground),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: sc.ctaBackground,
                foregroundColor: sc.ctaForeground,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterEmptyState(ScentleThemeColors sc) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 44, color: sc.mutedText),
            const SizedBox(height: 14),
            Text(
              'NO FLACONS FOUND',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: sc.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No flacons match the active filter or search query in your trophy cabinet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: sc.mutedText, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _selectedFilter = 'All');
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: sc.border),
                foregroundColor: sc.primaryText,
              ),
              child: const Text('RESET FILTERS'),
            ),
          ],
        ),
      ),
    );
  }
}
