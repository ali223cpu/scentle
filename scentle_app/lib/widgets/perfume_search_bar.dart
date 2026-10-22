import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/scentle_theme.dart';
import '../models/perfume_model.dart';
import '../providers/game_provider.dart';
import '../services/perfume_repository.dart';

/// Autocomplete fragrance search bar querying the in-memory 12,280 dataset in <5ms
/// with high-contrast 2px editorial border and zero-layout-shift floating OverlayPortal.
class PerfumeSearchBar extends StatefulWidget {
  final VoidCallback? onOpenGameOverModal;
  final ValueChanged<PerfumeModel>? onSelected;
  final Set<int>? excludedPerfumeIds;
  final bool? isGameOver;
  final bool enabled;
  final List<PerfumeModel> Function(String query)? onSearch;

  const PerfumeSearchBar({
    super.key,
    this.onOpenGameOverModal,
    this.onSelected,
    this.excludedPerfumeIds,
    this.isGameOver,
    this.enabled = true,
    this.onSearch,
  });

  @override
  State<PerfumeSearchBar> createState() => _PerfumeSearchBarState();
}

class _PerfumeSearchBarState extends State<PerfumeSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _portalController = OverlayPortalController();

  List<PerfumeModel> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _portalController.isShowing) {
      _portalController.hide();
    } else if (_focusNode.hasFocus &&
        _controller.text.trim().isNotEmpty &&
        !_portalController.isShowing) {
      _portalController.show();
    }
  }

  void _onQueryChanged() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = const []);
      }
      if (_portalController.isShowing) {
        _portalController.hide();
      }
      return;
    }

    final List<PerfumeModel> matches;
    if (widget.onSearch != null) {
      matches = widget.onSearch!(query);
    } else {
      final excluded = widget.excludedPerfumeIds ??
          (widget.onSelected == null
              ? context.read<GameProvider>().guessedPerfumeIds
              : <int>{});

      matches = PerfumeRepository.instance.search(
        query,
        excludeIds: excluded,
        limit: 8,
      );
    }

    setState(() => _suggestions = matches);

    if (!_portalController.isShowing && _focusNode.hasFocus) {
      _portalController.show();
    }
  }

  void _selectPerfume(PerfumeModel perfume) {
    HapticFeedback.lightImpact();
    _controller.clear();
    setState(() => _suggestions = const []);
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    _focusNode.unfocus();

    if (widget.onSelected != null) {
      widget.onSelected!(perfume);
    } else {
      context.read<GameProvider>().submitGuess(perfume);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOver = widget.isGameOver ??
        (widget.onSelected == null ? context.watch<GameProvider>().isGameOver : false);
    final sc = context.sc;

    if (isOver) {
      if (widget.onSelected != null) {
        return const SizedBox.shrink();
      }
      final game = context.watch<GameProvider>();
      return _buildGameOverControls(context, sc, game);
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: (context) {
          final query = _controller.text.trim();
          final hasNoResults = _suggestions.isEmpty && query.length >= 2;

          return CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 52),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 10,
                shadowColor: sc.cardShadow,
                borderRadius: BorderRadius.circular(12),
                color: sc.cardSurface,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width - 32,
                    maxHeight: 280,
                  ),
                  decoration: BoxDecoration(
                    color: sc.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sc.border, width: 1.2),
                  ),
                  child: hasNoResults
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text(
                            'No matching fragrances found. Check spelling or try searching by perfume house.',
                            style: TextStyle(
                              fontSize: 12,
                              color: sc.mutedText,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          physics: const ClampingScrollPhysics(),
                          itemCount: _suggestions.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: sc.divider,
                          ),
                          itemBuilder: (context, index) {
                            final perfume = _suggestions[index];
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${perfume.brand} ',
                                      style: TextStyle(
                                        color: sc.accent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    TextSpan(
                                      text: perfume.name,
                                      style: TextStyle(
                                        color: sc.primaryText,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              subtitle: Text(
                                perfume.perfumer != 'Unknown'
                                    ? 'Nose: ${perfume.perfumer}'
                                    : (perfume.country != 'Unknown' ? perfume.country : ''),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: sc.mutedText,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: sc.surfaceSecondary,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: sc.border),
                                ),
                                child: Text(
                                  '${perfume.year > 0 ? perfume.year : ""} ${perfume.gender}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: sc.mutedText,
                                  ),
                                ),
                              ),
                              onTap: () => _selectPerfume(perfume),
                            );
                          },
                        ),
                ),
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: sc.cardSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focusNode.hasFocus ? sc.inputBorder : sc.border,
              width: _focusNode.hasFocus ? 2.0 : 1.2,
            ),
            boxShadow: [
              if (_focusNode.hasFocus)
                BoxShadow(
                  color: sc.cardShadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              if (_suggestions.isNotEmpty) {
                _selectPerfume(_suggestions.first);
              }
            },
            style: TextStyle(
              color: sc.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Search fragrance, house, year, or nose...',
              hintStyle: TextStyle(
                color: sc.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: _focusNode.hasFocus ? sc.primaryText : sc.mutedText,
                size: 20,
              ),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 18, color: sc.mutedText),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _suggestions = const []);
                        if (_portalController.isShowing) {
                          _portalController.hide();
                        }
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverControls(
    BuildContext context,
    ScentleThemeColors sc,
    GameProvider game,
  ) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: widget.onOpenGameOverModal,
            icon: Icon(Icons.analytics_outlined, size: 20, color: sc.ctaForeground),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'VIEW FULL BREAKDOWN & SHARE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: sc.ctaForeground,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: sc.ctaBackground,
              foregroundColor: sc.ctaForeground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
        ),
        if (game.currentMode == GameMode.unlimited) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => game.startUnlimitedGame(),
              icon: Icon(Icons.refresh, size: 18, color: sc.primaryText),
              label: Text(
                'NEXT MYSTERY SCENT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: sc.primaryText,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: sc.primaryText,
                side: BorderSide(color: sc.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
