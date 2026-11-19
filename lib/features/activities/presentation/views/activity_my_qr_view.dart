import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/sac_font_size.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_state_panel.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_status_style.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../qr/presentation/providers/qr_member_token_provider.dart';
import '../../../virtual_card/presentation/widgets/virtual_card_qr_tile.dart';
import '../providers/activities_providers.dart';

/// "Mi asistencia": the member's QR, big and bright, for a leader to scan.
/// While open it polls the activity; once the member shows up in the
/// attendees the panel turns into "Asistencia registrada" and the QR fades.
class ActivityMyQrView extends ConsumerStatefulWidget {
  const ActivityMyQrView({
    super.key,
    required this.activityId,
    required this.activityName,
    this.sectionName,
    this.pollInterval = const Duration(seconds: 5),
  });

  final int activityId;
  final String activityName;
  final String? sectionName;

  /// How often the activity is refreshed while the screen is open.
  final Duration pollInterval;

  @override
  ConsumerState<ActivityMyQrView> createState() => _ActivityMyQrViewState();
}

class _ActivityMyQrViewState extends ConsumerState<ActivityMyQrView> {
  Timer? _timer;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _raiseBrightness();
    _timer = Timer.periodic(widget.pollInterval, (_) {
      if (!mounted || _registered) return;
      ref.invalidate(activityDetailProvider(widget.activityId));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restoreBrightness();
    super.dispose();
  }

  Future<void> _raiseBrightness() async {
    try {
      await ScreenBrightness().setApplicationScreenBrightness(1.0);
    } catch (_) {
      // Unsupported platform: the QR still works.
    }
  }

  Future<void> _restoreBrightness() async {
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (_) {}
  }

  bool _isRegistered(List<String>? attendees, String? userId) =>
      userId != null && (attendees?.contains(userId) ?? false);

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final userId = ref.watch(authNotifierProvider.select((v) => v.value?.id));
    final userName =
        ref.watch(authNotifierProvider.select((v) => v.value?.name)) ?? '';
    final attendees =
        ref.watch(activityDetailProvider(widget.activityId)).value?.attendees;
    final registered = _isRegistered(attendees, userId);

    ref.listen(activityDetailProvider(widget.activityId), (_, next) {
      final now = _isRegistered(next.value?.attendees, userId);
      if (now && !_registered) {
        HapticFeedback.mediumImpact();
        _timer?.cancel();
      }
      _registered = now;
    });
    _registered = registered;

    final token = ref.watch(qrMemberTokenProvider);
    final section = widget.sectionName?.trim() ?? '';
    final who = [userName, if (section.isNotEmpty) section]
        .where((e) => e.isNotEmpty)
        .join(' · ');
    final reduceMotion = SacMotion.reduceMotionOf(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'activities.attendance.my_title'.tr(),
        subtitle: widget.activityName,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _statePanel(context, registered),
          const SizedBox(height: 24),
          AnimatedOpacity(
            opacity: registered ? 0.12 : 1,
            duration: reduceMotion ? Duration.zero : SacMotion.standard,
            curve: SacMotion.easeOut,
            child: ExcludeSemantics(
              excluding: registered,
              child: Center(
                child: token.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(48),
                    child: SacLoading(),
                  ),
                  error: (error, _) => SacErrorState(
                    title: 'qr.errors.scan_failed'.tr(),
                    message: userErrorMessage(error),
                    padding: const EdgeInsets.all(16),
                    onRetry: () => ref.invalidate(qrMemberTokenProvider),
                  ),
                  data: (value) => VirtualCardQrTile(
                    data: value.token,
                    maxSize: 300,
                    padding: 16,
                    showShadow: true,
                  ),
                ),
              ),
            ),
          ),
          if (who.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              who,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                color: c.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statePanel(BuildContext context, bool registered) {
    if (registered) {
      final title = 'activities.attendance.done_title'.tr();
      return SacStatePanel(
        key: const ValueKey('my-qr-panel'),
        style: SacStatusStyle.of(
          context,
          SacStatusKind.validated,
          label: title,
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        ),
        title: title,
        message: 'activities.attendance.done_body'.tr(),
      );
    }
    final title = 'activities.attendance.code_title'.tr();
    return SacStatePanel(
      key: const ValueKey('my-qr-panel'),
      style: SacStatusStyle.of(
        context,
        SacStatusKind.pending,
        label: title,
        icon: HugeIcons.strokeRoundedQrCode01,
      ),
      title: title,
      message: 'activities.attendance.code_body'.tr(),
    );
  }
}
