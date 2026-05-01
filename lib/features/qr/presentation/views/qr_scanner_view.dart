import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/qr_scan_result.dart';
import '../providers/qr_scan_provider.dart';

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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScanResultSheet(state: state),
    );

    if (!mounted) return;
    ref.read(qrScanProvider.notifier).reset();
    setState(() => _handling = false);
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.activityId != null
              ? 'qr.scan_attendance_title'.tr()
              : 'qr.scan_title'.tr(),
        ),
        actions: [
          IconButton(
            tooltip: 'qr.torch_tooltip'.tr(),
            onPressed: () => _controller.toggleTorch(),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedFlash,
              color: Colors.white,
              size: 22,
            ),
          ),
          IconButton(
            tooltip: 'qr.switch_camera_tooltip'.tr(),
            onPressed: () => _controller.switchCamera(),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedCameraRotated02,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          const _ScanOverlay(),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: _HintCard(activityId: widget.activityId),
          ),
        ],
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 13),
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        );
      },
    );
  }
}

class _ScanResultSheet extends StatelessWidget {
  const _ScanResultSheet({required this.state});
  final AsyncValue<QrScanResult?> state;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: state.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, _) => _ErrorBody(error: err),
        data: (result) => result == null
            ? const SizedBox.shrink()
            : _SuccessBody(result: result),
      ),
    );
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.result});
  final QrScanResult result;

  @override
  Widget build(BuildContext context) {
    final member = result.member;
    final attendance = result.attendance;
    final subtitle = [member.clubName, member.sectionName]
        .whereType<String>()
        .join(' · ');

    String? attendanceLabel;
    if (attendance != null) {
      attendanceLabel = attendance.alreadyPresent
          ? 'qr.scan_success_already_present'.tr()
          : 'qr.scan_success_registered'.tr();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              color: Colors.green,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (attendanceLabel != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: attendance!.alreadyPresent
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              attendanceLabel,
              style: TextStyle(
                color: attendance.alreadyPresent
                    ? Colors.orange.shade900
                    : Colors.green.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('qr.scan_another'.tr()),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HugeIcon(
          icon: HugeIcons.strokeRoundedAlert02,
          color: Colors.red,
          size: 32,
        ),
        const SizedBox(height: 12),
        Text(
          'qr.scan_error_title'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          qrScanErrorMessageKey(error).tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.retry'.tr()),
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
