import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/constants/maps_constants.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Resultado devuelto por [LocationPickerView] al confirmar una ubicación.
class LocationPickerResult {
  /// Nombre o dirección del lugar seleccionado.
  final String name;

  /// Latitud de la ubicación.
  final double lat;

  /// Longitud de la ubicación.
  final double long;

  const LocationPickerResult({
    required this.name,
    required this.lat,
    required this.long,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

/// Pantalla de selección de ubicación con Google Maps.
///
/// Muestra un mapa a pantalla completa con:
/// - Barra de búsqueda en la parte superior (geocodificación de texto)
/// - Pin central que sigue el movimiento de la cámara
/// - Tarjeta inferior con la dirección resuelta y botón de confirmación
///
/// Uso:
/// ```dart
/// final result = await Navigator.push<LocationPickerResult>(
///   context,
///   MaterialPageRoute(builder: (_) => const LocationPickerView()),
/// );
/// if (result != null) { ... }
/// ```
///
/// NOTA: Requiere que la API Key de Google Maps esté configurada en:
///   - Android: AndroidManifest.xml → com.google.android.geo.API_KEY
///   - iOS: AppDelegate.swift → GMSServices.provideAPIKey(...)
/// Ver [MapsConstants] para instrucciones detalladas.
class LocationPickerView extends StatefulWidget {
  /// Ubicación inicial del mapa. Si es null, usa la ubicación por defecto
  /// definida en [MapsConstants] (Ciudad de México).
  final LatLng? initialLocation;

  const LocationPickerView({super.key, this.initialLocation});

  @override
  State<LocationPickerView> createState() => _LocationPickerViewState();
}

class _LocationPickerViewState extends State<LocationPickerView> {
  // ── Controladores ─────────────────────────────────────────────────────────
  final Completer<GoogleMapController> _mapController = Completer();

  // ── Estado ────────────────────────────────────────────────────────────────
  late LatLng _currentCenter;
  String _resolvedAddress = 'Cargando dirección...';
  bool _isResolvingAddress = false;

  /// Temporizador para evitar llamadas excesivas a geocoding mientras
  /// el usuario arrastra el mapa.
  Timer? _geocodeDebounce;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialLocation ??
        const LatLng(MapsConstants.defaultLat, MapsConstants.defaultLong);
    // Resolver dirección de la ubicación inicial
    _resolveAddressForLatLng(_currentCenter);
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    super.dispose();
  }

  // ── Geocoding ─────────────────────────────────────────────────────────────

  /// Convierte coordenadas en dirección legible usando reverse geocoding.
  Future<void> _resolveAddressForLatLng(LatLng latLng) async {
    setState(() {
      _isResolvingAddress = true;
      _resolvedAddress = 'Obteniendo dirección...';
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final parts = <String>[];

        if (place.name != null && place.name!.isNotEmpty) {
          parts.add(place.name!);
        }
        if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
          parts.add(place.thoroughfare!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          parts.add(place.locality!);
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          parts.add(place.administrativeArea!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          parts.add(place.country!);
        }

        final address = parts.isNotEmpty
            ? parts.join(', ')
            : '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';

        if (mounted) {
          setState(() {
            _resolvedAddress = address;
            _isResolvingAddress = false;
          });
        }
      }
    } catch (_) {
      // Si geocoding falla (sin internet, key inválida, etc.), mostrar coords
      if (mounted) {
        setState(() {
          _resolvedAddress =
              '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
          _isResolvingAddress = false;
        });
      }
    }
  }

  /// Geocodificación directa: convierte texto en coordenadas.
  Future<LatLng?> _geocodeAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (_) {
      // Geocoding falló — devuelve null para indicarlo al llamador
    }
    return null;
  }

  // ── Handlers del mapa ─────────────────────────────────────────────────────

  void _onCameraMove(CameraPosition position) {
    _currentCenter = position.target;
    // Cancelar cualquier resolución pendiente mientras el usuario sigue arrastrando
    _geocodeDebounce?.cancel();
  }

  void _onCameraIdle() {
    // Esperar 600 ms de quietud antes de llamar a geocoding
    _geocodeDebounce = Timer(const Duration(milliseconds: 600), () {
      _resolveAddressForLatLng(_currentCenter);
    });
  }

  Future<void> _animateTo(LatLng target, {double zoom = MapsConstants.searchResultZoom}) async {
    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: zoom),
      ),
    );
  }

  void _onConfirm() {
    Navigator.of(context).pop(
      LocationPickerResult(
        name: _resolvedAddress,
        lat: _currentCenter.latitude,
        long: _currentCenter.longitude,
      ),
    );
  }

  // ── Búsqueda ──────────────────────────────────────────────────────────────

  Future<void> _openSearch() async {
    final query = await showSearch<String?>(
      context: context,
      delegate: _LocationSearchDelegate(),
    );

    if (query == null || query.trim().isEmpty || !mounted) return;

    final latLng = await _geocodeAddress(query.trim());
    if (latLng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se encontró esa dirección. Intenta ser más específico.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    _currentCenter = latLng;
    await _animateTo(latLng);
    _resolveAddressForLatLng(latLng);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // ── Mapa a pantalla completa ──────────────────────────────
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentCenter,
                zoom: MapsConstants.defaultZoom,
              ),
              onMapCreated: (controller) {
                _mapController.complete(controller);
              },
              onCameraMove: _onCameraMove,
              onCameraIdle: _onCameraIdle,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
            ),

            // ── Pin central (fijo en el centro de la pantalla) ────────
            _CenterPin(),

            // ── AppBar flotante ───────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _FloatingAppBar(
                onBack: () => Navigator.pop(context),
                onSearch: _openSearch,
              ),
            ),

            // ── Tarjeta inferior con dirección y botón ────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _LocationBottomCard(
                address: _resolvedAddress,
                isLoading: _isResolvingAddress,
                lat: _currentCenter.latitude,
                long: _currentCenter.longitude,
                onConfirm: _onConfirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets internos
// ─────────────────────────────────────────────────────────────────────────────

/// AppBar flotante semitransparente con sombra suave.
class _FloatingAppBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onSearch;

  const _FloatingAppBar({required this.onBack, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final c = context.sac;

    return Container(
      padding: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.45),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Botón volver
          _MapIconButton(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            onPressed: onBack,
            tooltip: 'Volver',
          ),
          const SizedBox(width: 10),

          // Barra de búsqueda tappable
          Expanded(
            child: GestureDetector(
              onTap: onSearch,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedSearch01,
                      size: 18,
                      color: c.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Buscar dirección o lugar...',
                      style: TextStyle(
                        fontSize: 14,
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pin central fijo — indica el punto que se está seleccionando.
class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sombra del pin
          Container(
            width: 10,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 2),
          // Cuerpo del pin
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.location_pin,
              color: Colors.white,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta inferior con dirección resuelta y botón de confirmación.
class _LocationBottomCard extends StatelessWidget {
  final String address;
  final bool isLoading;
  final double lat;
  final double long;
  final VoidCallback onConfirm;

  const _LocationBottomCard({
    required this.address,
    required this.isLoading,
    required this.lat,
    required this.long,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle visual
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Etiqueta
          Text(
            'Ubicación seleccionada',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),

          // Dirección
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedLocation01,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLoading)
                      _ShimmerLine(width: 200, height: 16)
                    else
                      Text(
                        address,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                          height: 1.3,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${lat.toStringAsFixed(5)}, ${long.toStringAsFixed(5)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textTertiary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Botón confirmar
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onConfirm,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedTick02,
                size: 20,
                color: Colors.white,
              ),
              label: const Text(
                'Confirmar ubicación',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón redondo flotante sobre el mapa.
class _MapIconButton extends StatelessWidget {
  final dynamic icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _MapIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: HugeIcon(icon: icon, size: 20, color: c.text),
          ),
        ),
      ),
    );
  }
}

/// Línea animada de carga tipo shimmer (simple, sin paquetes externos).
class _ShimmerLine extends StatefulWidget {
  final double width;
  final double height;

  const _ShimmerLine({required this.width, required this.height});

  @override
  State<_ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<_ShimmerLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: c.border.withValues(alpha: _anim.value),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delegado de búsqueda
// ─────────────────────────────────────────────────────────────────────────────

/// Delegado para el buscador de lugares usando [showSearch].
///
/// Devuelve la cadena que el usuario ingresó (sin hacer geocoding aquí —
/// la geocodificación la hace [_LocationPickerViewState._openSearch]).
class _LocationSearchDelegate extends SearchDelegate<String?> {
  _LocationSearchDelegate()
      : super(
          searchFieldLabel: 'Buscar dirección o lugar...',
          keyboardType: TextInputType.streetAddress,
          textInputAction: TextInputAction.search,
        );

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedCancel01,
            size: 20,
            color: context.sac.textSecondary,
          ),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: HugeIcon(
        icon: HugeIcons.strokeRoundedArrowLeft01,
        size: 20,
        color: context.sac.text,
      ),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // Al confirmar la búsqueda, devolver la cadena al llamador
    WidgetsBinding.instance.addPostFrameCallback((_) {
      close(context, query.trim());
    });
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final c = context.sac;

    if (query.isEmpty) {
      return _SearchEmptyHint(c: c);
    }

    // Mostrar una sugerencia simple: buscar tal cual el texto ingresado
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedSearch01,
          size: 18,
          color: AppColors.primary,
        ),
      ),
      title: Text(
        'Buscar "$query"',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: c.text,
        ),
      ),
      subtitle: Text(
        'Toca para buscar esta dirección en el mapa',
        style: TextStyle(fontSize: 12, color: c.textSecondary),
      ),
      onTap: () => close(context, query.trim()),
    );
  }
}

/// Pantalla de ayuda cuando la búsqueda está vacía.
class _SearchEmptyHint extends StatelessWidget {
  final SacColors c;
  const _SearchEmptyHint({required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedLocation01,
                size: 34,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Busca una dirección',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Escribe el nombre de un lugar, calle o colonia para localizarlo en el mapa.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'También puedes arrastrar el mapa directamente al lugar deseado.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: c.textTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
