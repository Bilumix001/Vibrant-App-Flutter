// lib/screens/map_screen.dart
// NOTA: esta pantalla ya NO tiene su propio Scaffold/AppBar.
// Ahora vive dentro de `MainShell` (ver main_shell.dart).
// Los botones de "vista satelital" y "centrar mapa" (antes en el AppBar)
// se movieron a iconos flotantes sobre el mapa, arriba a la derecha.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/destination_model.dart';
import '../providers/destination_provider.dart';
import '../providers/theme_provider.dart';

// ── PALETA ────────────────────────────────────────────
const _greenDark   = Color(0xFF047857);
const _greenBright = Color(0xFF05c46b);
const _greenLight  = Color(0xFF34d399);

// ── CONFIGURACIÓN DE MARCADORES ───────────────────────
const _popularSize      = 36.0;
const _popularIconSize  = 20.0;
const _normalSize       = 14.0;
const _selectedSize     = 44.0;
const _selectedIconSize = 24.0;

// ── ALTURAS DEL PANEL ─────────────────────────────────
const _kExpanded  = 0.55;
const _kCollapsed = 0.26;
const _kMin       = 0.08;

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController    = MapController();
  final _searchController = TextEditingController();
  final _panelController  = DraggableScrollableController();

  DestinationModel? _selected;
  bool   _showRoute   = false;
  bool   _isSatellite = false;
  String _searchQuery = '';

  // ── FILTROS ───────────────────────────────────────────
  String? _filterDept;
  double? _filterMinRating;
  bool    _filterWithRoute = false;
  bool    _filterOnlyTop15 = false;

  bool get _hasActiveFilters =>
      _filterDept != null ||
      _filterMinRating != null ||
      _filterWithRoute ||
      _filterOnlyTop15;

  int get _activeFilterCount =>
      (_filterDept      != null ? 1 : 0) +
      (_filterMinRating != null ? 1 : 0) +
      (_filterWithRoute          ? 1 : 0) +
      (_filterOnlyTop15          ? 1 : 0);

  static const _peruCenter  = LatLng(-9.19, -75.0152);
  static const _initialZoom = 5.5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(destinationProvider.notifier).load();
    });
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() =>
      setState(() => _searchQuery = _searchController.text);

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _panelController.dispose();
    super.dispose();
  }

  // ── SELECCIÓN ─────────────────────────────────────────
  void _selectDestination(DestinationModel dest) {
    setState(() {
      _selected    = dest;
      _showRoute   = false;
      _searchQuery = '';
    });
    _searchController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    _mapController.move(
      LatLng(dest.latitude, dest.longitude),
      dest.isTop15 ? 13.0 : 11.0,
    );
    if (_panelController.isAttached) {
      _panelController.animateTo(
        _kCollapsed,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _clearSelection() {
    setState(() {
      _selected  = null;
      _showRoute = false;
    });
    if (_panelController.isAttached) {
      _panelController.animateTo(
        _kExpanded,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _toggleRoute() {
    if (_selected == null || !_selected!.hasRoute) return;
    setState(() => _showRoute = !_showRoute);
  }

  // ── FILTROS ───────────────────────────────────────────
  void _openFilters(List<String> departments) {
    final isDark = ref.read(themeProvider);

    // Copias locales para editar dentro del sheet
    String? localDept      = _filterDept;
    double? localMinRating = _filterMinRating;
    bool    localWithRoute = _filterWithRoute;
    bool    localOnlyTop15 = _filterOnlyTop15;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => _FilterSheet(
          isDark:       isDark,
          departments:  departments,
          selectedDept: localDept,
          minRating:    localMinRating,
          withRoute:    localWithRoute,
          onlyTop15:    localOnlyTop15,
          onDeptChanged:    (v) => setModal(() => localDept      = v),
          onRatingChanged:  (v) => setModal(() => localMinRating = v),
          onRouteChanged:   (v) => setModal(() => localWithRoute = v),
          onTop15Changed:   (v) => setModal(() => localOnlyTop15 = v),
          onApply: () {
            setState(() {
              _filterDept      = localDept;
              _filterMinRating = localMinRating;
              _filterWithRoute = localWithRoute;
              _filterOnlyTop15 = localOnlyTop15;
            });
            Navigator.pop(context);
          },
          onClear: () => setModal(() {
            localDept      = null;
            localMinRating = null;
            localWithRoute = false;
            localOnlyTop15 = false;
          }),
        ),
      ),
    );
  }

  void _clearFilters() => setState(() {
    _filterDept      = null;
    _filterMinRating = null;
    _filterWithRoute = false;
    _filterOnlyTop15 = false;
  });

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return _greenBright;
    }
  }

  @override
  Widget build(BuildContext context) {
    final destState = ref.watch(destinationProvider);
    final isDark    = ref.watch(themeProvider);

    final tileUrl = _isSatellite
        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/'
          'World_Imagery/MapServer/tile/{z}/{y}/{x}'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    // ── Top 15 ────────────────────────────────────────
    final top15 = destState.destinations
        .where((d) => d.isTop15)
        .toList()
      ..sort((a, b) => a.ranking!.compareTo(b.ranking!));

    final top15Ids  = top15.map((d) => d.id).toSet();
    final restDests = destState.destinations
        .where((d) => !top15Ids.contains(d.id))
        .toList();

    // ── Sugerencias de búsqueda ───────────────────────
    final suggestions = _searchQuery.isEmpty
        ? <DestinationModel>[]
        : destState.destinations.where((d) {
            final q = _searchQuery.toLowerCase();
            return d.name.toLowerCase().contains(q) ||
                   d.department.toLowerCase().contains(q) ||
                   d.province.toLowerCase().contains(q) ||
                   d.district.toLowerCase().contains(q);
          }).take(12).toList();

    // ── Departamentos disponibles para el filtro ──────
    final departments = destState.destinations
        .map((d) => d.department)
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    // ── Aplicar filtros ───────────────────────────────
    var filteredDests = destState.destinations.toList();
    if (_filterDept != null) {
      filteredDests = filteredDests
          .where((d) => d.department == _filterDept)
          .toList();
    }
    if (_filterMinRating != null) {
      filteredDests = filteredDests
          .where((d) => (d.googleRating ?? 0) >= _filterMinRating!)
          .toList();
    }
    if (_filterWithRoute) {
      filteredDests = filteredDests.where((d) => d.hasRoute).toList();
    }
    if (_filterOnlyTop15) {
      filteredDests = filteredDests.where((d) => d.isTop15).toList();
    }

    return Container(
      color: isDark ? const Color(0xFF141414) : const Color(0xFFE8FFF2),
      child: Stack(
        children: [

          // ── MAPA ───────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _peruCenter,
              initialZoom:   _initialZoom,
              minZoom: 3.0,
              maxZoom: 18.0,
              onTap: (_, __) {
                _clearSelection();
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            children: [
              TileLayer(
                urlTemplate:          tileUrl,
                userAgentPackageName: 'com.vibrantperu.app',
              ),
              if (_showRoute && _selected != null && _selected!.hasRoute)
                PolylineLayer(polylines: [
                  Polyline(
                    points:            _selected!.route!.coordinates,
                    color:             _hexToColor(_selected!.route!.color),
                    strokeWidth:       4.0,
                    borderColor:       Colors.white.withValues(alpha: 0.6),
                    borderStrokeWidth: 1.5,
                  ),
                ]),

              // Marcadores normales (no top15)
              MarkerLayer(
                markers: restDests.map((dest) {
                  final isSelected = _selected?.id == dest.id;
                  final size = isSelected ? _selectedSize : _normalSize;
                  return Marker(
                    point:  LatLng(dest.latitude, dest.longitude),
                    width:  size, height: size,
                    child: GestureDetector(
                      onTap: () => _selectDestination(dest),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _greenBright
                              : _greenDark.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white
                                .withValues(alpha: isSelected ? 1.0 : 0.5),
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: _greenBright.withValues(alpha: 0.6),
                              blurRadius: 10, spreadRadius: 1,
                            ),
                          ] : null,
                        ),
                        child: isSelected
                            ? Icon(Icons.location_on,
                                color: Colors.white, size: _selectedIconSize)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Marcadores top15
              MarkerLayer(
                markers: top15.map((dest) {
                  final isSelected = _selected?.id == dest.id;
                  final size     = isSelected ? _selectedSize : _popularSize;
                  final iconSize = isSelected ? _selectedIconSize : _popularIconSize;
                  return Marker(
                    point:  LatLng(dest.latitude, dest.longitude),
                    width:  size, height: size,
                    child: GestureDetector(
                      onTap: () => _selectDestination(dest),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected ? _greenBright : _greenDark,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white,
                              width: isSelected ? 3 : 2),
                          boxShadow: [
                            BoxShadow(
                              color: _greenBright.withValues(
                                  alpha: isSelected ? 0.75 : 0.45),
                              blurRadius:   isSelected ? 16 : 8,
                              spreadRadius: isSelected ? 2  : 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          dest.hasRoute ? Icons.route : Icons.location_on,
                          color: Colors.white, size: iconSize,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ── LOADING ─────────────────────────────────────
          if (destState.isLoading)
            const Center(
              child: CircularProgressIndicator(color: _greenBright)),

          // ── ERROR ────────────────────────────────────────
          if (destState.error != null)
            Positioned(
              top: 12, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(destState.error!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13)),
              ),
            ),

          // ── BOTONES FLOTANTES ─────────────────────────
          Positioned(
            top: 12, right: 12,
            child: Column(children: [
              _MapFab(
                icon: _isSatellite ? Icons.map : Icons.satellite_alt,
                tooltip:
                    _isSatellite ? 'Vista normal' : 'Vista satelital',
                isDark: isDark,
                onTap: () =>
                    setState(() => _isSatellite = !_isSatellite),
              ),
              const SizedBox(height: 10),
              _MapFab(
                icon: Icons.my_location,
                tooltip: 'Centrar mapa',
                isDark: isDark,
                onTap: () {
                  _mapController.move(_peruCenter, _initialZoom);
                  _clearSelection();
                },
              ),
            ]),
          ),

          // ── LEYENDA + CONTADOR ───────────────────────
          if (!destState.isLoading &&
              destState.destinations.isNotEmpty)
            Positioned(
              top: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF141414).withValues(alpha: 0.93)
                      : Colors.white.withValues(alpha: 0.93),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _greenDark.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: _greenDark,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: _greenBright
                                  .withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Top ${top15.length}',
                        style: TextStyle(
                          color: isDark ? _greenLight : _greenDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          color: _greenDark.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color:
                                  Colors.white.withValues(alpha: 0.5),
                              width: 0.8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${restDests.length} otros',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : Colors.black45,
                          fontSize: 11,
                        ),
                      ),
                    ]),
                    if (_isSatellite) ...[
                      const SizedBox(height: 4),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.satellite_alt,
                            size: 11,
                            color: isDark
                                ? Colors.white38
                                : Colors.black38),
                        const SizedBox(width: 4),
                        Text('Satélite',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white38
                                  : Colors.black38,
                              fontSize: 10,
                            )),
                      ]),
                    ],
                  ],
                ),
              ),
            ),

          // ── PANEL INFERIOR DESLIZABLE ─────────────────
          DraggableScrollableSheet(
            controller:       _panelController,
            initialChildSize: _kExpanded,
            minChildSize:     _kMin,
            maxChildSize:     _kExpanded,
            snap:             true,
            snapSizes:        const [_kMin, _kCollapsed, _kExpanded],
            builder: (context, scrollController) => _BottomPanel(
              scrollController:  scrollController,
              isDark:            isDark,
              selected:          _selected,
              top15:             top15,
              suggestions:       suggestions,
              filteredDests:     filteredDests,
              hasActiveFilters:  _hasActiveFilters,
              activeFilterCount: _activeFilterCount,
              searchController:  _searchController,
              isSearching:       _searchQuery.isNotEmpty,
              showRoute:         _showRoute,
              filterDept:        _filterDept,
              filterMinRating:   _filterMinRating,
              filterWithRoute:   _filterWithRoute,
              filterOnlyTop15:   _filterOnlyTop15,
              onSelectDest:      _selectDestination,
              onClose:           _clearSelection,
              onToggleRoute:     _selected?.hasRoute == true
                                     ? _toggleRoute
                                     : null,
              onFilterTap:       () => _openFilters(departments),
              onClearFilters:    _clearFilters,
              onRemoveDeptFilter:    () =>
                  setState(() => _filterDept = null),
              onRemoveRatingFilter:  () =>
                  setState(() => _filterMinRating = null),
              onRemoveRouteFilter:   () =>
                  setState(() => _filterWithRoute = false),
              onRemoveTop15Filter:   () =>
                  setState(() => _filterOnlyTop15 = false),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// PANEL INFERIOR DESLIZABLE
// ═══════════════════════════════════════════════════════
class _BottomPanel extends StatelessWidget {
  final ScrollController        scrollController;
  final bool                    isDark;
  final DestinationModel?       selected;
  final List<DestinationModel>  top15;
  final List<DestinationModel>  suggestions;
  final List<DestinationModel>  filteredDests;
  final bool                    hasActiveFilters;
  final int                     activeFilterCount;
  final TextEditingController   searchController;
  final bool                    isSearching;
  final bool                    showRoute;
  final String?                 filterDept;
  final double?                 filterMinRating;
  final bool                    filterWithRoute;
  final bool                    filterOnlyTop15;
  final ValueChanged<DestinationModel> onSelectDest;
  final VoidCallback            onClose;
  final VoidCallback?           onToggleRoute;
  final VoidCallback            onFilterTap;
  final VoidCallback            onClearFilters;
  final VoidCallback            onRemoveDeptFilter;
  final VoidCallback            onRemoveRatingFilter;
  final VoidCallback            onRemoveRouteFilter;
  final VoidCallback            onRemoveTop15Filter;

  const _BottomPanel({
    required this.scrollController,
    required this.isDark,
    required this.selected,
    required this.top15,
    required this.suggestions,
    required this.filteredDests,
    required this.hasActiveFilters,
    required this.activeFilterCount,
    required this.searchController,
    required this.isSearching,
    required this.showRoute,
    required this.filterDept,
    required this.filterMinRating,
    required this.filterWithRoute,
    required this.filterOnlyTop15,
    required this.onSelectDest,
    required this.onClose,
    required this.onFilterTap,
    required this.onClearFilters,
    required this.onRemoveDeptFilter,
    required this.onRemoveRatingFilter,
    required this.onRemoveRouteFilter,
    required this.onRemoveTop15Filter,
    this.onToggleRoute,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: isDark ? 0.5 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        children: [

          // Handle de arrastre
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SearchBarWidget(
              controller:       searchController,
              isDark:           isDark,
              activeFilterCount: activeFilterCount,
              onFilterTap:      onFilterTap,
            ),
          ),

          // Chips de filtros activos
          if (hasActiveFilters && selected == null) ...[
            const SizedBox(height: 10),
            _ActiveFilterChips(
              isDark:          isDark,
              filterDept:      filterDept,
              filterMinRating: filterMinRating,
              filterWithRoute: filterWithRoute,
              filterOnlyTop15: filterOnlyTop15,
              onRemoveDept:    onRemoveDeptFilter,
              onRemoveRating:  onRemoveRatingFilter,
              onRemoveRoute:   onRemoveRouteFilter,
              onRemoveTop15:   onRemoveTop15Filter,
              onClearAll:      onClearFilters,
            ),
          ],

          const SizedBox(height: 16),

          // Contenido según estado
          if (selected != null)
            _DestinationCard(
              destination:   selected!,
              isDark:        isDark,
              showRoute:     showRoute,
              onClose:       onClose,
              onToggleRoute: onToggleRoute,
            )
          else if (isSearching)
            suggestions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 32, horizontal: 16),
                    child: Center(
                      child: Column(children: [
                        Icon(Icons.search_off,
                            size: 40,
                            color: isDark
                                ? Colors.white24
                                : Colors.black26),
                        const SizedBox(height: 8),
                        Text(
                          'No se encontraron destinos',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : Colors.black38,
                            fontSize: 14,
                          ),
                        ),
                      ]),
                    ),
                  )
                : _SuggestionsList(
                    suggestions: suggestions,
                    isDark:      isDark,
                    onSelect:    onSelectDest,
                  )
          else if (hasActiveFilters)
            _FilteredResultsSection(
              results:  filteredDests,
              isDark:   isDark,
              onSelect: onSelectDest,
              onClear:  onClearFilters,
            )
          else
            _TopDestinosSection(
              top15:    top15,
              isDark:   isDark,
              onSelect: onSelectDest,
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// BARRA DE BÚSQUEDA (con badge de filtros)
// ═══════════════════════════════════════════════════════
class _SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final bool         isDark;
  final int          activeFilterCount;
  final VoidCallback onFilterTap;

  const _SearchBarWidget({
    required this.controller,
    required this.isDark,
    required this.activeFilterCount,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? _greenDark.withValues(alpha: 0.18)
                  : const Color(0xFFE8FFF2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _greenDark.withValues(
                    alpha: isDark ? 0.4 : 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Botón de filtro con badge
                GestureDetector(
                  onTap: onFilterTap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.tune,
                          color: activeFilterCount > 0
                              ? _greenBright
                              : _greenDark.withValues(alpha: 0.8),
                          size: 20),
                      if (activeFilterCount > 0)
                        Positioned(
                          top: -5, right: -6,
                          child: Container(
                            width: 14, height: 14,
                            decoration: const BoxDecoration(
                              color: _greenBright,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$activeFilterCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF064E3B),
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar destinos',
                      hintStyle: TextStyle(
                        color: isDark
                            ? Colors.white38
                            : Colors.black38,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12),
                    ),
                  ),
                ),
                if (controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => controller.clear(),
                    child: Icon(Icons.close,
                        color: isDark
                            ? Colors.white38
                            : Colors.black38,
                        size: 16),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 46, height: 46,
          decoration: const BoxDecoration(
            color: _greenBright,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x4005c46b),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.search,
              color: Colors.white, size: 22),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// CHIPS DE FILTROS ACTIVOS
// ═══════════════════════════════════════════════════════
class _ActiveFilterChips extends StatelessWidget {
  final bool    isDark;
  final String? filterDept;
  final double? filterMinRating;
  final bool    filterWithRoute;
  final bool    filterOnlyTop15;
  final VoidCallback onRemoveDept;
  final VoidCallback onRemoveRating;
  final VoidCallback onRemoveRoute;
  final VoidCallback onRemoveTop15;
  final VoidCallback onClearAll;

  const _ActiveFilterChips({
    required this.isDark,
    required this.filterDept,
    required this.filterMinRating,
    required this.filterWithRoute,
    required this.filterOnlyTop15,
    required this.onRemoveDept,
    required this.onRemoveRating,
    required this.onRemoveRoute,
    required this.onRemoveTop15,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (filterDept != null)
            _FilterChip(
              label: '📍 $filterDept',
              isDark: isDark,
              onRemove: onRemoveDept,
            ),
          if (filterMinRating != null)
            _FilterChip(
              label: '⭐ ${filterMinRating!.toStringAsFixed(1)}+',
              isDark: isDark,
              onRemove: onRemoveRating,
            ),
          if (filterWithRoute)
            _FilterChip(
              label: '🗺 Con recorrido',
              isDark: isDark,
              onRemove: onRemoveRoute,
            ),
          if (filterOnlyTop15)
            _FilterChip(
              label: '🏆 Solo Top 15',
              isDark: isDark,
              onRemove: onRemoveTop15,
            ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClearAll,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'Limpiar todo',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String       label;
  final bool         isDark;
  final VoidCallback onRemove;

  const _FilterChip({
    required this.label,
    required this.isDark,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _greenDark.withValues(alpha: isDark ? 0.3 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _greenDark.withValues(alpha: isDark ? 0.6 : 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? _greenLight : _greenDark,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close,
                size: 12,
                color: isDark
                    ? _greenLight.withValues(alpha: 0.7)
                    : _greenDark.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// SECCIÓN TOP DESTINOS
// ═══════════════════════════════════════════════════════
class _TopDestinosSection extends StatelessWidget {
  final List<DestinationModel>         top15;
  final bool                            isDark;
  final ValueChanged<DestinationModel> onSelect;

  const _TopDestinosSection({
    required this.top15,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (top15.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Cargando destinos...',
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 14,
            ),
          ),
        ),
      );
    }
    return _DestCardList(
      title:    'Top Destinos Turísticos',
      items:    top15,
      isDark:   isDark,
      onSelect: onSelect,
    );
  }
}

// ═══════════════════════════════════════════════════════
// SECCIÓN RESULTADOS FILTRADOS
// ═══════════════════════════════════════════════════════
class _FilteredResultsSection extends StatelessWidget {
  final List<DestinationModel>         results;
  final bool                            isDark;
  final ValueChanged<DestinationModel> onSelect;
  final VoidCallback                   onClear;

  const _FilteredResultsSection({
    required this.results,
    required this.isDark,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.filter_list_off,
                  size: 48,
                  color: isDark
                      ? Colors.white24
                      : Colors.black26),
              const SizedBox(height: 12),
              Text(
                'Sin resultados con estos filtros',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Intenta ajustar o limpiar los filtros',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_greenDark, _greenBright],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Limpiar filtros',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _DestCardList(
      title:    'Resultados filtrados (${results.length})',
      items:    results,
      isDark:   isDark,
      onSelect: onSelect,
    );
  }
}

// ── Lista de cards reutilizable ───────────────────────
class _DestCardList extends StatelessWidget {
  final String                          title;
  final List<DestinationModel>          items;
  final bool                            isDark;
  final ValueChanged<DestinationModel>  onSelect;

  const _DestCardList({
    required this.title,
    required this.items,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: const TextStyle(
              color: _greenDark,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 215,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _TopDestCard(
              dest:   items[i],
              isDark: isDark,
              onTap:  () => onSelect(items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// CARD DE DESTINO (horizontal scroll)
// ═══════════════════════════════════════════════════════
class _TopDestCard extends StatelessWidget {
  final DestinationModel dest;
  final bool isDark;
  final VoidCallback onTap;

  const _TopDestCard({
    required this.dest,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? const Color(0xFF252527)
        : const Color(0xFFF7FFFE);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 172,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _greenDark.withValues(
                alpha: isDark ? 0.35 : 0.2),
            width: 1,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
              child: SizedBox(
                height: 112, width: double.infinity,
                child: dest.imageUrl.isNotEmpty
                    ? Image.network(
                        dest.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _ImgPlaceholder(),
                      )
                    : const _ImgPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre + badge top
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dest.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _greenDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (dest.isTop15) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: _greenBright
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${dest.ranking}',
                            style: const TextStyle(
                              color: _greenBright,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dest.locationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 11,
                    ),
                  ),
                  // Rating si disponible
                  if (dest.googleRating != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFC107), size: 12),
                      const SizedBox(width: 3),
                      Text(
                        dest.googleRating!.toStringAsFixed(1),
                        style: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : Colors.black54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (dest.googleUserRatingsTotal != null) ...[
                        const SizedBox(width: 3),
                        Text(
                          '(${_formatCount(dest.googleUserRatingsTotal!.toInt())})',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : Colors.black38,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ]),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      dest.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? _greenLight.withValues(alpha: 0.65)
                            : _greenDark.withValues(alpha: 0.6),
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}k';
    return '$n';
  }
}

// ── Placeholder de imagen ──────────────────────────────
class _ImgPlaceholder extends StatelessWidget {
  const _ImgPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [Color(0xFF064E3B), Color(0xFF047857)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.landscape, color: Colors.white38, size: 38),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// LISTA DE SUGERENCIAS DE BÚSQUEDA
// ═══════════════════════════════════════════════════════
class _SuggestionsList extends StatelessWidget {
  final List<DestinationModel>         suggestions;
  final bool                            isDark;
  final ValueChanged<DestinationModel> onSelect;

  const _SuggestionsList({
    required this.suggestions,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: suggestions
          .map((d) => _SuggestionTile(
                dest:   d,
                isDark: isDark,
                onTap:  () => onSelect(d),
              ))
          .toList(),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final DestinationModel dest;
  final bool isDark;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.dest,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: _greenBright.withValues(alpha: 0.08),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white10 : Colors.black12,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: dest.isTop15
                    ? _greenDark
                    : _greenDark.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                dest.isTop15
                    ? Icons.star_rounded
                    : Icons.location_on,
                color: Colors.white, size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dest.name,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF064E3B),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (dest.locationLabel.isNotEmpty)
                    Text(
                      dest.locationLabel,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (dest.isTop15)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _greenBright.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _greenBright.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '#${dest.ranking}',
                  style: const TextStyle(
                    color: _greenBright,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// CARD DEL DESTINO SELECCIONADO (dentro del panel)
// ═══════════════════════════════════════════════════════
class _DestinationCard extends StatelessWidget {
  final DestinationModel destination;
  final bool          isDark;
  final bool          showRoute;
  final VoidCallback  onClose;
  final VoidCallback? onToggleRoute;

  const _DestinationCard({
    required this.destination,
    required this.isDark,
    required this.showRoute,
    required this.onClose,
    this.onToggleRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141414) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _greenDark.withValues(alpha: 0.3), width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _greenDark.withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    destination.hasRoute
                        ? Icons.route
                        : Icons.location_on,
                    color: _greenBright, size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              destination.name,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF064E3B),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (destination.isTop15)
                            Container(
                              margin:
                                  const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _greenBright
                                    .withValues(alpha: 0.15),
                                borderRadius:
                                    BorderRadius.circular(8),
                                border: Border.all(
                                  color: _greenBright
                                      .withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '⭐ #${destination.ranking}',
                                style: const TextStyle(
                                  color: _greenBright,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (destination.locationLabel.isNotEmpty)
                        Text(
                          destination.locationLabel,
                          style: TextStyle(
                            color: isDark
                                ? _greenLight.withValues(alpha: 0.7)
                                : _greenDark.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(Icons.close,
                      color:
                          isDark ? Colors.white38 : Colors.black26,
                      size: 20),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              destination.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 13, height: 1.45,
              ),
            ),
            // Rating
            if (destination.googleRating != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFFFC107), size: 14),
                const SizedBox(width: 4),
                Text(
                  '${destination.googleRating!.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (destination.googleUserRatingsTotal != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    '· ${_fmtCount(destination.googleUserRatingsTotal!.toInt())} reseñas',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white38
                          : Colors.black38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ]),
            ],
            if (onToggleRoute != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onToggleRoute,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: showRoute
                        ? null
                        : const LinearGradient(
                            colors: [_greenDark, _greenBright],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    color: showRoute
                        ? _greenBright.withValues(alpha: 0.12)
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    border: showRoute
                        ? Border.all(color: _greenBright, width: 1)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        showRoute
                            ? Icons.visibility_off
                            : Icons.route,
                        color: showRoute
                            ? _greenBright
                            : Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        showRoute
                            ? 'Ocultar recorrido'
                            : 'Ver recorrido',
                        style: TextStyle(
                          color: showRoute
                              ? _greenBright
                              : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}k';
    return '$n';
  }
}

// ═══════════════════════════════════════════════════════
// SHEET DE FILTROS
// ═══════════════════════════════════════════════════════
class _FilterSheet extends StatelessWidget {
  final bool         isDark;
  final List<String> departments;
  final String?      selectedDept;
  final double?      minRating;
  final bool         withRoute;
  final bool         onlyTop15;
  final ValueChanged<String?> onDeptChanged;
  final ValueChanged<double?> onRatingChanged;
  final ValueChanged<bool>    onRouteChanged;
  final ValueChanged<bool>    onTop15Changed;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.isDark,
    required this.departments,
    required this.selectedDept,
    required this.minRating,
    required this.withRoute,
    required this.onlyTop15,
    required this.onDeptChanged,
    required this.onRatingChanged,
    required this.onRouteChanged,
    required this.onTop15Changed,
    required this.onApply,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Título
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                const Icon(Icons.tune, color: _greenDark, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Filtrar destinos',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF064E3B),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onClear,
                  child: const Text(
                    'Limpiar',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            color: isDark ? Colors.white12 : Colors.black12,
            height: 1,
          ),

          const SizedBox(height: 16),

          // ── Departamento ───────────────────────────
          _FilterSection(
            title: 'Departamento',
            isDark: isDark,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _OptionChip(
                    label: 'Todos',
                    selected: selectedDept == null,
                    isDark: isDark,
                    onTap: () => onDeptChanged(null),
                  ),
                  ...departments.map((dept) => _OptionChip(
                    label: dept,
                    selected: selectedDept == dept,
                    isDark: isDark,
                    onTap: () => onDeptChanged(
                        selectedDept == dept ? null : dept),
                  )),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Calificación mínima ────────────────────
          _FilterSection(
            title: 'Calificación mínima',
            isDark: isDark,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _OptionChip(
                    label: 'Todas',
                    selected: minRating == null,
                    isDark: isDark,
                    onTap: () => onRatingChanged(null),
                  ),
                  _OptionChip(
                    label: '3.5 ★+',
                    selected: minRating == 3.5,
                    isDark: isDark,
                    onTap: () => onRatingChanged(
                        minRating == 3.5 ? null : 3.5),
                  ),
                  _OptionChip(
                    label: '4.0 ★+',
                    selected: minRating == 4.0,
                    isDark: isDark,
                    onTap: () => onRatingChanged(
                        minRating == 4.0 ? null : 4.0),
                  ),
                  _OptionChip(
                    label: '4.5 ★+',
                    selected: minRating == 4.5,
                    isDark: isDark,
                    onTap: () => onRatingChanged(
                        minRating == 4.5 ? null : 4.5),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Opciones adicionales ───────────────────
          _FilterSection(
            title: 'Opciones',
            isDark: isDark,
            child: Column(
              children: [
                _SwitchRow(
                  label:    'Solo con recorrido disponible',
                  icon:     Icons.route,
                  value:    withRoute,
                  isDark:   isDark,
                  onChanged: onRouteChanged,
                ),
                _SwitchRow(
                  label:    'Solo Top 15 destinos',
                  icon:     Icons.emoji_events_rounded,
                  value:    onlyTop15,
                  isDark:   isDark,
                  onChanged: onTop15Changed,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Botón Aplicar ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: onApply,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_greenDark, _greenBright],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _greenBright.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Aplicar filtros',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sección de filtro con título ───────────────────────
class _FilterSection extends StatelessWidget {
  final String title;
  final bool   isDark;
  final Widget child;

  const _FilterSection({
    required this.title,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 10),
          child: Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

// ── Chip de opción ────────────────────────────────────
class _OptionChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final bool         isDark;
  final VoidCallback onTap;

  const _OptionChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? _greenDark
              : isDark
                  ? Colors.white10
                  : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? _greenBright.withValues(alpha: 0.6)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : isDark
                    ? Colors.white70
                    : Colors.black54,
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Switch row ────────────────────────────────────────
class _SwitchRow extends StatelessWidget {
  final String              label;
  final IconData            icon;
  final bool                value;
  final bool                isDark;
  final ValueChanged<bool>  onChanged;

  const _SwitchRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: value
                  ? _greenBright
                  : isDark
                      ? Colors.white38
                      : Colors.black38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _greenBright,
            activeTrackColor: _greenDark.withValues(alpha: 0.5),
            inactiveThumbColor:
                isDark ? Colors.white38 : Colors.black26,
            inactiveTrackColor:
                isDark ? Colors.white12 : Colors.black12,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// BOTÓN FLOTANTE SOBRE EL MAPA
// ═══════════════════════════════════════════════════════
class _MapFab extends StatelessWidget {
  final IconData     icon;
  final String       tooltip;
  final bool         isDark;
  final VoidCallback onTap;

  const _MapFab({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _greenDark,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}