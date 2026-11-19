import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../activities/presentation/providers/activities_providers.dart';
import '../../domain/entities/qr_scan_result.dart';
import '../providers/qr_scan_provider.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/animations/sac_draw_reveal.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

class QrScannerView extends ConsumerStatefulWidget {
  const QrScannerView({super.key, this.activityId});

  /// Optional activity — when present, each successful scan also registers
  /// attendance. Omit to run the scanner in pure identity-lookup mode.
  final int? activityId;

  @override
  ConsumerState<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends ConsumerState<QrScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _handling = false;

  /// People registered during this session, on top of the roster's confirmed
  /// ones, to show "n of total" without refetching after every scan.
  final Set<String> _scanned = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final barcode = capture.barcodes.firstWhere(
      (b) => b.rawValue != null && b.rawValue!.isNotEmpty,
      orElse: () => const Barcode(),
    );
    final token = barcode.rawValue;
    if (token == null || token.isEmpty) return;

    setState(() => _handling = true);
    await _controller.stop();

    await ref.read(qrScanProvider.notifier).submit(
          token: token,
          activityId: widget.activityId,
        );

    if (!mounted) return;
    final state = ref.read(qrScanProvider);
    if (state.hasValue && state.value != null) HapticFeedback.mediumImpact();

    final result = state.value;
    if (result?.attendance != null) _scanned.add(result!.member.userId);
    final roster = widget.activityId == null
        ? null
        : ref.read(attendanceRosterProvider(widget.activityId!)).value;
    final registeredCount = roster == null
        ? null
        : {
            ...roster.where((m) => m.confirmed).map((m) => m.userId),
            ..._scanned,
          }.length;

    await showSacSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QrScanResultSheet(
        state: state,
        registeredCount: registeredCount,
        total: roster?.length,
      ),
    );

    if (!mounted) return;
    ref.read(qrScanProvider.notifier).reset();
    setState(() => _handling = false);
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the roster loaded while the scanner is open (for "n of total").
    final activityId = widget.activityId;
    if (activityId != null) ref.watch(attendanceRosterProvider(activityId));
    return Scaffold(
      appBar: SacTopBar(
        title: widget.activityId != null
            ? 'qr.scan_attendance_title'.tr()
            : 'qr.scan_title'.tr(),
        actions: [
          SacPressable(
            listenOnly: true,
            child: IconButton(
              enableFeedback: false,
              tooltip: 'qr.torch_tooltip'.tr(),
              onPressed: () => _controller.toggleTorch(),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedFlash,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          SacPressable(
            listenOnly: true,
            child: IconButton(
              enableFeedback: false,
              tooltip: 'qr.switch_camera_tooltip'.tr(),
              onPressed: () => _controller.switchCamera(),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedCameraRotated02,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => QrCameraErrorView(
              errorCode: error.errorCode,
              onRetry: () => _controller.start(),
            ),
          ),
          // Hide the viewfinder frame and hint while the camera is unusable.
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (state.error != null) return const SizedBox.shrink();
              return Stack(
                fit: StackFit.expand,
                children: [
                  const _ScanOverlay(),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 32,
                    child: _HintCard(activityId: widget.activityId),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the camera preview when the scanner cannot start.
///
/// Permission denied gets an "Abrir ajustes" CTA, because once the OS has
/// denied camera access the app can no longer prompt again.
class QrCameraErrorView extends StatelessWidget {
  const QrCameraErrorView({
    super.key,
    required this.errorCode,
    required this.onRetry,
    this.onOpenSettings = openAppSettings,
  });

  final MobileScannerErrorCode errorCode;
  final VoidCallback onRetry;
  final Future<bool> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final denied = errorCode == MobileScannerErrorCode.permissionDenied;
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: denied
                    ? HugeIcons.strokeRoundedCameraOff01
                    : HugeIcons.strokeRoundedCamera01,
                color: Colors.white,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                (denied
                        ? 'qr.camera.permission_denied_title'
                        : 'qr.camera.unavailable_title')
                    .tr(),
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                (denied
                        ? 'qr.camera.permission_denied_body'
                        : 'qr.camera.unavailable_body')
                    .tr(),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              if (denied) ...[
                SacButton(
                  text: 'qr.camera.open_settings'.tr(),
                  variant: SacButtonVariant.primary,
                  fullWidth: false,
                  onPressed: () => onOpenSettings(),
                ),
                const SizedBox(height: 8),
              ],
              SacButton(
                text: 'common.retry'.tr(),
                variant: denied
                    ? SacButtonVariant.secondary
                    : SacButtonVariant.primary,
                fullWidth: false,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.activityId});
  final int? activityId;

  @override
  Widget build(BuildContext context) {
    final label = activityId != null
        ? 'qr.scan_hint_attendance'.tr()
        : 'qr.scan_hint_lookup'.tr();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white, fontSize: SacFontSize.bodyMedium),
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth * 0.7;
        return Center(
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet with the result of a scan: the person (photo, name, check)
/// and, with an activity, "Attendance registered · n of total".
@visibleForTesting
class QrScanResultSheet extends StatelessWidget {
  const QrScanResultSheet({
    super.key,
    required this.state,
    this.registeredCount,
    this.total,
  });

  final AsyncValue<QrScanResult?> state;

  /// People registered so far, including this scan. Null: unknown.
  final int? registeredCount;

  /// Members of the activity's sections. Null: unknown.
  final int? total;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLG)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: state.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: SacLoading(),
          ),
        ),
        error: (err, _) => _ErrorBody(error: err),
        data: (result) => result == null
            ? const SizedBox.shrink()
            : _SuccessBody(
                result: result,
                registeredCount: registeredCount,
                total: total,
              ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            color: c.error,
            size: 44,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'qr.scan_error_title'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: SacFontSize.headlineSmall,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          qrScanErrorMessageKey(error).tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: SacFontSize.bodyMedium,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        SacButton(
          text: 'common.retry'.tr(),
          variant: SacButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({
    required this.result,
    required this.registeredCount,
    required this.total,
  });
  final QrScanResult result;
  final int? registeredCount;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final member = result.member;
    final attendance = result.attendance;
    final subtitle =
        [member.clubName, member.sectionName].whereType<String>().join(' · ');

    String? attendanceLabel;
    if (attendance != null) {
      if (attendance.alreadyPresent) {
        attendanceLabel = 'qr.scan_success_already_present'.tr();
      } else if (registeredCount != null && total != null) {
        attendanceLabel = 'qr.scan_success_registered_count'.tr(
          namedArgs: {'count': '$registeredCount', 'total': '$total'},
        );
      } else {
        attendanceLabel = 'qr.scan_success_registered'.tr();
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SacMemberAvatar(
                imageUrl: member.avatar,
                name: member.fullName,
                size: 72,
              ),
              Positioned(
                right: -6,
                bottom: -6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: SacDrawReveal(
                      child: HugeIcon(
                        key: const ValueKey('scan-check'),
                        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                        color: c.success,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          member.fullName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: SacFontSize.headlineSmall,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        if (attendanceLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            attendanceLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              fontWeight: FontWeight.w600,
              color: attendance!.alreadyPresent
                  ? c.textSecondary
                  : c.onSuccessContainer,
            ),
          ),
        ],
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SacFontSize.bodySmall,
              color: c.textTertiary,
            ),
          ),
        ],
        const SizedBox(height: 20),
        SacButton(
          text: 'qr.scan_another'.tr(),
          variant: SacButtonVariant.primary,
          icon: HugeIcons.strokeRoundedQrCode01,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

String qrScanErrorMessageKey(Object error) {
  if (error is ConnectionException) {
    return 'common.error_network';
  }

  return 'qr.errors.scan_failed';
}
