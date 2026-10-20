import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/device_pair_link.dart';
import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/device_pairing.dart';
import '../../domain/utils/device_label.dart';
import '../providers/device_meta_provider.dart';
import '../providers/device_notice_provider.dart';
import 'pairing_qr_scanner_view.dart';

/// Pantalla para vincular este teléfono como el de un menor de 13 (FP3-52).
///
/// Se llega desde el login («Vincular este teléfono de un niño»), con un enlace
/// `sacdia://pair?t=...` o al perder la vinculación. Escanea el QR que muestra
/// el tutor, deja nombrar el teléfono y canjea el token.
///
/// - Con una sesión de cuenta se niega («cierra sesión primero») y NO llama a
///   la API ni escanea nada.
/// - Un QR que no es de vinculación da un mensaje único y no llama a la API.
/// - Tras cualquier fallo del canje hay que escanear de nuevo: el token es de
///   un solo uso y no se conserva.
class PairDeviceView extends ConsumerStatefulWidget {
  const PairDeviceView({super.key, this.scannerBuilder});

  /// Para pruebas: sustituye la cámara por una pantalla que devuelva el valor
  /// leído.
  final WidgetBuilder? scannerBuilder;

  @override
  ConsumerState<PairDeviceView> createState() => _PairDeviceViewState();
}

class _PairDeviceViewState extends ConsumerState<PairDeviceView> {
  final _labelController = TextEditingController();
  bool _labelTouched = false;

  /// Token canjeable. Solo en memoria de esta pantalla.
  String? _token;
  bool _busy = false;
  bool _invalidQr = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _adoptPendingLink());
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  bool get _loggedIn => ref.read(authNotifierProvider).valueOrNull != null;

  /// Un enlace que llegó con la app arrancando. Con una sesión de cuenta se
  /// descarta sin usarlo (la pantalla ya se niega).
  void _adoptPendingLink() {
    if (!mounted) return;
    final link = ref.read(pairingLinkProvider);
    if (link == null) return;
    ref.read(pairingLinkProvider.notifier).state = null;
    if (_loggedIn) return;
    setState(() {
      _token = link;
      _invalidQr = false;
      _error = null;
    });
  }

  Future<void> _scan() async {
    if (_busy || _loggedIn) return;
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: widget.scannerBuilder ?? (_) => const PairingQrScannerView(),
      ),
    );
    if (!mounted || raw == null) return;
    final uri = Uri.tryParse(raw.trim());
    final token = uri == null ? null : pairingTokenFromUri(uri);
    setState(() {
      _token = token;
      _invalidQr = token == null;
      _error = null;
    });
  }

  Future<void> _submit(DevicePairingMeta meta) async {
    final token = _token;
    if (token == null || _busy || _loggedIn) return;
    final typed = sanitizeDeviceLabel(_labelController.text);
    final label = typed.isNotEmpty
        ? typed
        : (meta.defaultLabel.isNotEmpty
            ? meta.defaultLabel
            : 'device.pair.fallback_label'.tr());
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref.read(authNotifierProvider.notifier).pairDevice(
          DevicePairingInput(
            pairingToken: token,
            label: label,
            platform: meta.platform,
            appVersion: meta.appVersion,
          ),
        );
    if (!mounted) return;
    // Éxito: el router lleva al inicio del dispositivo en cuanto cambia la
    // sesión; no hay nada más que hacer aquí.
    if (error == null) return;
    setState(() {
      _busy = false;
      _error = error;
      // El token es de un solo uso: tras un fallo se escanea de nuevo.
      _token = null;
    });
  }

  void _backToLogin() {
    ref.read(deviceNoticeProvider.notifier).state = null;
    context.go(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    // Un enlace que llega con esta pantalla ya abierta (p. ej. tras una
    // revocación) no la reconstruye: go_router termina en la misma ruta.
    ref.listen<String?>(pairingLinkProvider, (_, next) {
      if (next != null) _adoptPendingLink();
    });
    final loggedIn =
        ref.watch(authNotifierProvider.select((v) => v.valueOrNull != null));
    final notice = ref.watch(deviceNoticeProvider);
    final meta = ref.watch(devicePairingMetaProvider).valueOrNull;

    if (_token != null && !_labelTouched && meta != null) {
      if (_labelController.text.isEmpty && meta.defaultLabel.isNotEmpty) {
        _labelController.text = meta.defaultLabel;
      }
    }

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: Responsive.formPadding(context),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: Responsive.maxFormWidth),
              child: loggedIn
                  ? _Refused(onClose: _close)
                  : _PairBody(
                      notice: notice,
                      onDismissNotice: () =>
                          ref.read(deviceNoticeProvider.notifier).state = null,
                      token: _token,
                      busy: _busy,
                      invalidQr: _invalidQr,
                      error: _error,
                      labelController: _labelController,
                      onLabelChanged: (_) => _labelTouched = true,
                      onScan: _scan,
                      onSubmit: meta == null ? null : () => _submit(meta),
                      onBack: _backToLogin,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.splash);
    }
  }
}

class _Refused extends StatelessWidget {
  const _Refused({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedUserLock01,
            size: 44,
            color: SacAccent.of(context).color,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'device.pair.refused.title'.tr(),
          key: const ValueKey('pair_refused_title'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'device.pair.refused.body'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: c.textSecondary,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 24),
        SacButton.outline(
          key: const ValueKey('pair_refused_close'),
          text: 'device.pair.refused.close'.tr(),
          onPressed: onClose,
        ),
      ],
    );
  }
}

class _PairBody extends StatelessWidget {
  const _PairBody({
    required this.notice,
    required this.onDismissNotice,
    required this.token,
    required this.busy,
    required this.invalidQr,
    required this.error,
    required this.labelController,
    required this.onLabelChanged,
    required this.onScan,
    required this.onSubmit,
    required this.onBack,
  });

  final DeviceNotice? notice;
  final VoidCallback onDismissNotice;
  final String? token;
  final bool busy;
  final bool invalidQr;
  final String? error;
  final TextEditingController labelController;
  final ValueChanged<String> onLabelChanged;
  final VoidCallback onScan;
  final VoidCallback? onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final scanned = token != null;
    final message = invalidQr ? 'device.pair.errors.invalid_qr'.tr() : error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedQrCode,
            size: 48,
            color: SacAccent.of(context).color,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'device.pair.title'.tr(),
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          (scanned ? 'device.pair.confirm_body' : 'device.pair.subtitle').tr(),
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: c.textSecondary,
            height: 1.4,
          ),
        ),
        if (notice != null) ...[
          const SizedBox(height: 16),
          _NoticeCard(
            key: const ValueKey('pair_notice'),
            message: (notice == DeviceNotice.sessionExpired
                    ? 'device.pair.notice.session_expired'
                    : 'device.pair.notice.unpaired')
                .tr(),
            onDismiss: onDismissNotice,
          ),
        ],
        const SizedBox(height: 24),
        if (scanned) ...[
          SacTextField(
            key: const ValueKey('pair_label_field'),
            controller: labelController,
            label: 'device.pair.label_title'.tr(),
            hint: 'device.pair.label_hint'.tr(),
            helperText: 'device.pair.label_help'.tr(),
            maxLength: 40,
            enabled: !busy,
            prefixIcon: HugeIcons.strokeRoundedSmartPhone01,
            onChanged: onLabelChanged,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
        ],
        if (message != null) ...[
          SacCard(
            key: const ValueKey('pair_error'),
            backgroundColor: AppColors.errorLight,
            borderColor: AppColors.error.withValues(alpha: 0.3),
            padding: const EdgeInsets.all(12),
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
                    message,
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
        ],
        if (scanned)
          SacButton.primary(
            key: const ValueKey('pair_submit'),
            text: (busy ? 'device.pair.linking' : 'device.pair.link').tr(),
            icon: HugeIcons.strokeRoundedLink01,
            isLoading: busy,
            onPressed: busy ? null : onSubmit,
          )
        else
          SacButton.primary(
            key: const ValueKey('pair_scan'),
            text: 'device.pair.scan'.tr(),
            icon: HugeIcons.strokeRoundedQrCode,
            onPressed: onScan,
          ),
        if (scanned && !busy) ...[
          const SizedBox(height: 8),
          SacButton.ghost(
            key: const ValueKey('pair_rescan'),
            text: 'device.pair.rescan'.tr(),
            onPressed: onScan,
          ),
        ],
        const SizedBox(height: 8),
        SacButton.ghost(
          key: const ValueKey('pair_back'),
          text: 'device.pair.back_to_login'.tr(),
          onPressed: busy ? null : onBack,
        ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard(
      {super.key, required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);
    return SacCard(
      backgroundColor: accent.light,
      borderColor: accent.color.withValues(alpha: 0.3),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            size: 20,
            color: accent.color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: context.sac.text, fontSize: 14),
            ),
          ),
          IconButton(
            tooltip: 'common.close'.tr(),
            onPressed: onDismiss,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              size: 18,
              color: context.sac.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
