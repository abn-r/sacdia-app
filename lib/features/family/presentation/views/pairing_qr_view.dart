import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/secure_screen.dart';
import '../../domain/entities/linked_device.dart';
import '../family_error_messages.dart';
import '../providers/linked_devices_providers.dart';

/// Muestra el QR para vincular el teléfono de un menor de 13 (FP3-41).
///
/// Al abrirse pide un token de un solo uso (10 min). El QR lleva
/// `sacdia://pair?c=<token>`; el niño lo escanea desde su teléfono. Mientras el
/// QR está vigente se pregunta cada pocos segundos si ya apareció un teléfono
/// nuevo para avisar al tutor. Al vencer se ofrece generar otro: un token nuevo
/// anula al anterior.
///
/// El token es un secreto: se protege la pantalla contra capturas, no se
/// registra y solo vive en la memoria de esta vista.
class PairingQrView extends ConsumerStatefulWidget {
  const PairingQrView({
    super.key,
    required this.dependentId,
    this.pollInterval = const Duration(seconds: 4),
    this.clock,
  });

  final String dependentId;

  /// Cada cuánto se revisa si ya se vinculó un teléfono.
  final Duration pollInterval;

  /// Reloj inyectable para las pruebas.
  final DateTime Function()? clock;

  @override
  ConsumerState<PairingQrView> createState() => _PairingQrViewState();
}

class _PairingQrViewState extends ConsumerState<PairingQrView> {
  DevicePairingToken? _token;
  Object? _error;
  bool _loading = false;
  bool _paired = false;
  Set<String> _baseline = const {};
  Timer? _tick;
  Timer? _poll;
  int _secondsLeft = 0;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _issue());
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  void _stopTimers() {
    _tick?.cancel();
    _poll?.cancel();
    _tick = null;
    _poll = null;
  }

  Future<void> _issue() async {
    if (_loading) return;
    _stopTimers();
    setState(() {
      _loading = true;
      _error = null;
      _paired = false;
    });
    final result = await ref
        .read(linkedDevicesActionsProvider)
        .issuePairingToken(widget.dependentId);
    if (!mounted) return;
    await result.fold(
      (failure) async {
        setState(() {
          _loading = false;
          _token = null;
          _error = failure;
        });
      },
      (token) async {
        // Los teléfonos que ya estaban vinculados: cualquiera nuevo es el del
        // niño.
        final known = await _activeIds();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _token = token;
          _baseline = known;
          _secondsLeft = token.secondsLeftAt(_now());
        });
        _startTimers();
      },
    );
  }

  Future<Set<String>> _activeIds() async {
    try {
      final devices =
          await ref.read(linkedDevicesActionsProvider).list(widget.dependentId);
      return {for (final d in devices.active) d.id};
    } catch (_) {
      return const {};
    }
  }

  void _startTimers() {
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final token = _token;
      if (!mounted || token == null) return;
      final left = token.secondsLeftAt(_now());
      if (left != _secondsLeft) setState(() => _secondsLeft = left);
      if (left == 0) _stopTimers();
    });
    _poll = Timer.periodic(widget.pollInterval, (_) => _checkPaired());
  }

  Future<void> _checkPaired() async {
    if (_paired || _token == null) return;
    final now = await _activeIds();
    if (!mounted || _paired) return;
    if (now.any((id) => !_baseline.contains(id))) {
      _stopTimers();
      ref.read(linkedDevicesActionsProvider).refresh(widget.dependentId);
      setState(() {
        _paired = true;
        _token = null;
      });
    }
  }

  void _done() {
    ref.read(linkedDevicesActionsProvider).refresh(widget.dependentId);
    if (context.canPop()) context.pop();
  }

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SecureScreen(
      child: Scaffold(
        backgroundColor: c.background,
        appBar: SacTopBar(
          title: 'family.devices.pair_title'.tr(),
          backgroundColor: c.background,
          foregroundColor: c.text,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.horizontalPadding(context),
              vertical: 16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: Responsive.maxFormWidth),
                child: _content(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: SacLoading()),
      );
    }
    if (_error != null) return _errorCard(context);
    if (_paired) return _pairedCard(context);
    final token = _token;
    if (token == null) {
      return const SizedBox.shrink();
    }
    return _qrCard(context, token);
  }

  Widget _errorCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacCard(
          key: const ValueKey('pairing_error'),
          backgroundColor: AppColors.errorLight,
          borderColor: AppColors.error.withValues(alpha: 0.3),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                size: 20,
                color: AppColors.errorDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  familyErrorMessage(_error),
                  style: const TextStyle(
                    color: AppColors.errorDark,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SacButton.outline(
          key: const ValueKey('pairing_retry'),
          text: 'common.retry'.tr(),
          icon: HugeIcons.strokeRoundedRefresh,
          onPressed: _issue,
        ),
      ],
    );
  }

  Widget _pairedCard(BuildContext context) {
    final c = context.sac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Center(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            size: 56,
            color: AppColors.validatedColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'family.devices.paired_title'.tr(),
          key: const ValueKey('pairing_success'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'family.devices.paired_body'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: c.textSecondary,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 24),
        SacButton.primary(
          key: const ValueKey('pairing_done'),
          text: 'common.done'.tr(),
          onPressed: _done,
        ),
      ],
    );
  }

  Widget _qrCard(BuildContext context, DevicePairingToken token) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final expired = _secondsLeft == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'family.devices.pair_instructions'.tr(),
          style: textTheme.bodyMedium?.copyWith(
            color: c.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        SacCard(
          child: Column(
            children: [
              Container(
                key: const ValueKey('pairing_qr'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: expired ? 0.08 : 1,
                      child: PairingQrCode(data: token.qrPayload),
                    ),
                    if (expired)
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedTimer02,
                        size: 48,
                        color: AppColors.errorDark,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                expired
                    ? 'family.devices.expired'.tr()
                    : 'family.devices.expires_in'
                        .tr(namedArgs: {'time': _format(_secondsLeft)}),
                key: const ValueKey('pairing_countdown'),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: expired ? AppColors.errorDark : c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedShield01,
              size: 18,
              color: SacAccent.of(context).color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'family.devices.pair_warning'.tr(),
                style: textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        expired
            ? SacButton.primary(
                key: const ValueKey('pairing_regenerate'),
                text: 'family.devices.regenerate'.tr(),
                icon: HugeIcons.strokeRoundedRefresh,
                onPressed: _issue,
              )
            : SacButton.outline(
                key: const ValueKey('pairing_regenerate'),
                text: 'family.devices.regenerate'.tr(),
                icon: HugeIcons.strokeRoundedRefresh,
                onPressed: _issue,
              ),
      ],
    );
  }
}

/// El QR del enlace de vinculación. Widget propio para que las pruebas puedan
/// leer lo que se codifica sin que el token viaje en una `Key` ni en un log.
class PairingQrCode extends StatelessWidget {
  const PairingQrCode({super.key, required this.data});

  /// `sacdia://pair?c=<token>`: un secreto de un solo uso.
  final String data;

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: 240,
      backgroundColor: Colors.white,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      semanticsLabel: 'family.devices.qr_alt'.tr(),
    );
  }
}
