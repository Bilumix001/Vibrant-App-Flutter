// lib/screens/map_screen.dart

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
// Popular → marcador grande y brillante
const _popularSize     = 36.0;
const _popularIconSize = 20.0;

// No popular → marcador pequeño y sutil
const _normalSize      = 14.0;
//const _normalIconSize  = 8.0;

// Seleccionado → siempre grande independiente del tipo
const _selectedSize     = 44.0;
const _selectedIconSize = 24.0;

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  DestinationModel? _selected;
  bool _showRoute   = false;
  bool _isSatellite = false;

  // Centro inicial: Perú
  static const _peruCenter  = LatLng(-9.19, -75.0152);
  static const _initialZoom = 5.5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(destinationProvider.notifier).load();
    });
  }

  void _selectDestination(DestinationModel dest) {
    setState(() {
      _selected  = dest;
      _showRoute = false;
    });
    // Zoom mayor para populares, menor para el resto
    _mapController.move(
      LatLng(dest.latitude, dest.longitude),
      dest.isPopular ? 13.0 : 11.0,
    );
  }

  void _clearSelection() => setState(() {
    _selected  = null;
    _showRoute = false;
  });

  void _toggleRoute() {
    if (_selected == null || !_selected!.hasRoute) return;
    setState(() => _showRoute = !_showRoute);
  }

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

    // Separar populares de no populares para renderizar los populares encima
    final nonPopular = destState.destinations.where((d) => !d.isPopular).toList();
    final popular    = destState.destinations.where((d) =>  d.isPopular).toList();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5FFF9),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF0A0A0A) : const Color(0xFF047857),
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [_greenLight, _greenBright],
          ).createShader(b),
          child: const Text(
            'Destinos Vibrant Perú',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isSatellite ? 'Vista normal' : 'Vista satelital',
            icon: Icon(
              _isSatellite ? Icons.map : Icons.satellite_alt,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _isSatellite = !_isSatellite),
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            tooltip: 'Centrar mapa',
            onPressed: () {
              _mapController.move(_peruCenter, _initialZoom);
              _clearSelection();
            },
          ),
        ],
      ),
      body: Stack(
        children: [

          // ── MAPA ───────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _peruCenter,
              initialZoom:   _initialZoom,
              minZoom:       3.0,
              maxZoom:       18.0,
              onTap: (_, __) => _clearSelection(),
            ),
            children: [

              TileLayer(
                urlTemplate:          tileUrl,
                userAgentPackageName: 'com.vibrantperu.app',
              ),

              // Polyline de ruta
              if (_showRoute && _selected != null && _selected!.hasRoute)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points:            _selected!.route!.coordinates,
                      color:             _hexToColor(_selected!.route!.color),
                      strokeWidth:       4.0,
                      borderColor:       Colors.white.withValues(alpha: 0.6),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),

              // ── MARCADORES NO POPULARES (pequeños, debajo) ──
              MarkerLayer(
                markers: nonPopular.map((dest) {
                  final isSelected = _selected?.id == dest.id;
                  final size = isSelected ? _selectedSize : _normalSize;

                  return Marker(
                    point:  LatLng(dest.latitude, dest.longitude),
                    width:  size,
                    height: size,
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
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _greenBright.withValues(alpha: 0.6),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? Icon(Icons.location_on,
                                color: Colors.white,
                                size: _selectedIconSize)
                            : null, // sin ícono cuando es pequeño
                      ),
                    ),
                  );
                }).toList(),
              ),

              // ── MARCADORES POPULARES (grandes, encima) ───
              MarkerLayer(
                markers: popular.map((dest) {
                  final isSelected = _selected?.id == dest.id;
                  final size = isSelected ? _selectedSize : _popularSize;
                  final iconSize = isSelected
                      ? _selectedIconSize
                      : _popularIconSize;

                  return Marker(
                    point:  LatLng(dest.latitude, dest.longitude),
                    width:  size,
                    height: size,
                    child: GestureDetector(
                      onTap: () => _selectDestination(dest),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected ? _greenBright : _greenDark,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: isSelected ? 3 : 2,
                          ),
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
                          color: Colors.white,
                          size:  iconSize,
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
              child: CircularProgressIndicator(color: _greenBright),
            ),

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
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),

          // ── LEYENDA + CONTADOR ───────────────────────────
          if (!destState.isLoading && destState.destinations.isNotEmpty)
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
                    color: _greenDark.withValues(alpha: 0.3), width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Populares
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(
                            color: _greenDark,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: _greenBright.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${popular.length} populares',
                          style: TextStyle(
                            color: isDark ? _greenLight : _greenDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // No populares
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                            color: _greenDark.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 0.8),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${nonPopular.length} otros',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (_isSatellite) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.satellite_alt,
                              size: 11,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.black38),
                          const SizedBox(width: 4),
                          Text(
                            'Satélite',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white38
                                  : Colors.black38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // ── CARD DEL DESTINO SELECCIONADO ───────────────
          if (_selected != null)
            Positioned(
              bottom: 24, left: 16, right: 16,
              child: _DestinationCard(
                destination:    _selected!,
                isDark:         isDark,
                showRoute:      _showRoute,
                onClose:        _clearSelection,
                onToggleRoute:  _selected!.hasRoute ? _toggleRoute : null,
              ),
            ),
        ],
      ),
    );
  }
}

// ── CARD DEL DESTINO ──────────────────────────────────
class _DestinationCard extends StatelessWidget {
  final DestinationModel destination;
  final bool         isDark;
  final bool         showRoute;
  final VoidCallback onClose;
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
    return Material(
      color: Colors.transparent,
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
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 16, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [

            // Header
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _greenDark.withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    destination.hasRoute ? Icons.route : Icons.location_on,
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
                          // Badge "Popular"
                          if (destination.isPopular)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _greenBright.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _greenBright.withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                '⭐ Popular',
                                style: TextStyle(
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
                      color: isDark ? Colors.white38 : Colors.black26,
                      size: 20),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Descripción
            Text(
              destination.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 13, height: 1.45,
              ),
            ),

            // Botón Ver recorrido
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
                        showRoute ? Icons.visibility_off : Icons.route,
                        color: showRoute ? _greenBright : Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        showRoute ? 'Ocultar recorrido' : 'Ver recorrido',
                        style: TextStyle(
                          color: showRoute ? _greenBright : Colors.white,
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
}