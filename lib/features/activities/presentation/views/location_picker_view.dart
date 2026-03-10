import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
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
// Modelo privado para resultados de Nominatim
// ─────────────────────────────────────────────────────────────────────────────

/// Resultado de la API de Nominatim con coordenadas y nombre del lugar.
class _NominatimPlace {
  final double lat;
  final double lon;
  final String displayName;

  const _NominatimPlace({
    required this.lat,
    required this.lon,
    required this.displayName,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

/// Pantalla de selección de ubicación con flutter_map (CartoDB Voyager tiles).
///
/// Muestra un mapa a pantalla completa con:
/// - Barra de búsqueda en la parte superior con autocompletado en tiempo real
///   usando la API de Nominatim (OpenStreetMap).
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
/// No requiere API Key de ningún proveedor.
class LocationPickerView extends StatefulWidget {
  /// Ubicación inicial del mapa. Si es null, usa la ubicación por defecto
  /// definida en [MapsConstants] (Ciudad de México).
  final LatLng? initialLocation;

  const LocationPickerView({super.key, this.initialLocation});

  @override
  State<LocationPickerView> createState() => _LocationPickerViewState();
}

class _LocationPickerViewState extends State<LocationPickerView>
    with TickerProviderStateMixin {
  // ── Controladores ─────────────────────────────────────────────────────────
  late final MapController _mapController;

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
    _mapController = MapController();
    _currentCenter = widget.initialLocation ??
        const LatLng(MapsConstants.defaultLat, MapsConstants.defaultLong);
    // Resolver dirección de la ubicación inicial
    _resolveAddressForLatLng(_currentCenter);
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _mapController.dispose();
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
      // Si geocoding falla (sin internet, etc.), mostrar coords
      if (mounted) {
        setState(() {
          _resolvedAddress =
              '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
          _isResolvingAddress = false;
        });
      }
    }
  }

  // ── Handlers del mapa ─────────────────────────────────────────────────────

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _currentCenter = camera.center;

    if (hasGesture) {
      // Cancelar cualquier resolución pendiente mientras el usuario arrastra
      _geocodeDebounce?.cancel();
      // Esperar 600 ms de quietud antes de llamar a geocoding
      _geocodeDebounce = Timer(const Duration(milliseconds: 600), () {
        _resolveAddressForLatLng(_currentCenter);
      });
    }
  }

  void _animateTo(LatLng target, {double zoom = MapsConstants.searchResultZoom}) {
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: target.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: target.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: zoom,
    );

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
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
    final place = await showSearch<_NominatimPlace?>(
      context: context,
      delegate: _LocationSearchDelegate(),
    );

    if (place == null || !mounted) return;

    final latLng = LatLng(place.lat, place.lon);
    _currentCenter = latLng;
    _animateTo(latLng);
    // Resolver dirección local para la tarjeta inferior (más limpio que display_name)
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
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentCenter,
                initialZoom: MapsConstants.defaultZoom,
                onPositionChanged: _onPositionChanged,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  userAgentPackageName: 'com.sacdia.app',
                  maxNativeZoom: 19,
                  maxZoom: 22,
                  additionalOptions: const {
                    'r': '@2x',
                  },
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('CartoDB', onTap: () {}),
                    TextSourceAttribution(
                      '© OpenStreetMap contributors',
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),

            // ── Pin central (fijo en el centro de la pantalla) ────────
            const _CenterPin(),

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
          // Sombra del pin
          Container(
            width: 10,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
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
// Delegado de búsqueda con autocompletado Nominatim
// ─────────────────────────────────────────────────────────────────────────────

/// Delegado para el buscador de lugares con sugerencias en tiempo real via
/// la API pública de Nominatim (OpenStreetMap).
///
/// Devuelve un [_NominatimPlace] con coordenadas y nombre del lugar
/// seleccionado, evitando una segunda llamada de geocodificación.
class _LocationSearchDelegate extends SearchDelegate<_NominatimPlace?> {
  _LocationSearchDelegate()
      : super(
          searchFieldLabel: 'Buscar dirección o lugar...',
          keyboardType: TextInputType.streetAddress,
          textInputAction: TextInputAction.search,
        );

  // ── Nominatim ─────────────────────────────────────────────────────────────

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://nominatim.openstreetmap.org',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'User-Agent': 'SACDIA App/1.0 (contact@sacdia.org)',
        'Accept-Language': 'es',
      },
    ),
  );

  // Estado interno del delegado
  List<_NominatimPlace> _results = [];
  bool _isLoading = false;
  bool _hasError = false;
  Timer? _debounce;
  String _lastQuery = '';

  /// Llama a Nominatim y actualiza resultados. Debounced 400ms.
  void _scheduleSearch(String q, void Function(void Function()) refresh) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      refresh(() {
        _results = [];
        _isLoading = false;
        _hasError = false;
      });
      return;
    }

    refresh(() {
      _isLoading = true;
      _hasError = false;
    });

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (q != _lastQuery) {
        _lastQuery = q;
        try {
          final response = await _dio.get<List<dynamic>>(
            '/search',
            queryParameters: {
              'q': q.trim(),
              'format': 'json',
              'limit': 5,
              'addressdetails': 1,
              'accept-language': 'es',
            },
          );

          final data = response.data ?? [];
          final places = data.map((item) {
            final map = item as Map<String, dynamic>;
            return _NominatimPlace(
              lat: double.parse(map['lat'] as String),
              lon: double.parse(map['lon'] as String),
              displayName: map['display_name'] as String,
            );
          }).toList();

          refresh(() {
            _results = places;
            _isLoading = false;
            _hasError = false;
          });
        } catch (_) {
          refresh(() {
            _results = [];
            _isLoading = false;
            _hasError = true;
          });
        }
      }
    });
  }

  // ── Helpers de formato ────────────────────────────────────────────────────

  /// Título: primeras 2 partes del display_name separadas por coma.
  String _placeTitle(String displayName) {
    final parts = displayName.split(', ');
    return parts.take(2).join(', ');
  }

  /// Subtítulo: partes restantes (desde la tercera en adelante).
  String _placeSubtitle(String displayName) {
    final parts = displayName.split(', ');
    if (parts.length <= 2) return '';
    return parts.skip(2).join(', ');
  }

  // ── SearchDelegate overrides ───────────────────────────────────────────────

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
          onPressed: () {
            query = '';
            _debounce?.cancel();
            _results = [];
            _isLoading = false;
            _hasError = false;
          },
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
      onPressed: () {
        _debounce?.cancel();
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // Cuando el usuario presiona "buscar" en el teclado, mostrar sugerencias
    return buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final c = context.sac;

    if (query.isEmpty) {
      return _SearchEmptyHint(c: c);
    }

    return StatefulBuilder(
      builder: (context, setState) {
        // Iniciar búsqueda cuando el query cambia
        if (query != _lastQuery || _isLoading == false && _results.isEmpty && !_hasError) {
          _scheduleSearch(query, (fn) {
            // Llamar setState del StatefulBuilder para refrescar la UI
            if (context.mounted) setState(fn);
          });
        }

        if (_isLoading) {
          return Center(
            child: LoadingAnimationWidget.inkDrop(
              color: AppColors.primary,
              size: 50,
            ),
          );
        }

        if (_hasError) {
          return _SearchStatusMessage(
            icon: HugeIcons.strokeRoundedWifiError01,
            title: 'Error de conexión',
            subtitle: 'Verifica tu internet e intenta de nuevo.',
            c: c,
          );
        }

        if (_results.isEmpty) {
          return _SearchStatusMessage(
            icon: HugeIcons.strokeRoundedLocation01,
            title: 'No se encontraron resultados',
            subtitle: 'Intenta con otro nombre o dirección.',
            c: c,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _results.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 68,
            color: c.border.withValues(alpha: 0.5),
          ),
          itemBuilder: (context, index) {
            final place = _results[index];
            final title = _placeTitle(place.displayName);
            final subtitle = _placeSubtitle(place.displayName);

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                padding: const EdgeInsets.all(8),
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
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: c.text,
                ),
              ),
              subtitle: subtitle.isNotEmpty
                  ? Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    )
                  : null,
              onTap: () {
                _debounce?.cancel();
                close(context, place);
              },
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets de estado para la búsqueda
// ─────────────────────────────────────────────────────────────────────────────

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

/// Mensaje genérico de estado (sin resultados / error de red).
class _SearchStatusMessage extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String subtitle;
  final SacColors c;

  const _SearchStatusMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: HugeIcon(
                icon: icon,
                size: 28,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
