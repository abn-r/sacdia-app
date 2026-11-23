import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/blood_type.dart';
import '../../../../core/widgets/secure_screen.dart';
import '../../../master_honors/presentation/widgets/master_honor_history_section.dart';
import '../../domain/entities/virtual_card.dart';
import '../providers/virtual_card_providers.dart';
import '../utils/credential_image_pdf.dart';
import '../utils/credential_share_capture.dart';
import '../utils/credential_share_files.dart';
import '../utils/share_position_origin.dart';
import '../widgets/credencial/credencial_card.dart';
import '../widgets/credencial/credencial_qr_fullscreen.dart';
import '../widgets/credencial/credencial_tokens.dart';
import '../widgets/credencial/credencial_view_model.dart';
import '../widgets/credencial/credential_parallax.dart';

/// How the credential is shared.
enum CredentialShareFormat { image, pdf }

/// What the QR on the card can do for [card].
CredencialQrState credentialQrStateOf(VirtualCard card) {
  if (card.isInactive) return CredencialQrState.suspended;
  if (!card.hasQr) return CredencialQrState.unavailable;
  if (card.isExpired) return CredencialQrState.expired;
  return CredencialQrState.ready;
}

class VirtualCardView extends ConsumerStatefulWidget {
  const VirtualCardView({super.key});

  @override
  ConsumerState<VirtualCardView> createState() => _VirtualCardViewState();
}

class _VirtualCardViewState extends ConsumerState<VirtualCardView> {
  final GlobalKey _shareBoundaryKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();

  /// Set while the image to share is being prepared: it draws the printable
  /// card (with its data rows) off screen so it can be captured.
  CredencialViewModel? _shareVm;

  bool get _sharing => _shareVm != null;

  Future<void> _refresh() async {
    ref.invalidate(virtualCardFetcherProvider);
    try {
      await ref.read(virtualCardFetcherProvider.future);
    } catch (_) {
      // The view shows the error; the refresh indicator still closes.
    }
  }

  void _openQr(CredencialViewModel vm, String heroTag) {
    // Root navigator: the QR covers the tab bar.
    Navigator.of(context, rootNavigator: true).push(
      SacFadeThroughRoute(
        builder: (_) => CredencialQrFullscreen(vm: vm, heroTag: heroTag),
      ),
    );
  }

  Future<void> _openShareSheet(CredencialViewModel vm) async {
    if (_sharing) return;
    final format = await showCredentialShareSheet(context);
    if (format == null || !mounted) return;
    await _share(vm, format);
  }

  Future<void> _share(
    CredencialViewModel vm,
    CredentialShareFormat format,
  ) async {
    setState(() => _shareVm = vm);
    final messenger = ScaffoldMessenger.of(context);
    final sharePositionOrigin = sharePositionOriginForContext(
      _shareButtonKey.currentContext ?? context,
    );
    final sharedFiles = <File>[];
    try {
      final pngBytes = await captureCredentialBoundaryPng(
        boundaryKey: _shareBoundaryKey,
        viewContext: context,
      );
      final safeFolio = vm.folio.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final tempDir = await getTemporaryDirectory();
      // Leftovers from a previous share (the app may have died in the grace).
      await sweepCredentialShareFiles(tempDir);

      final XFile shared;
      if (format == CredentialShareFormat.pdf) {
        final pdfBytes = await buildCredentialImagePdf(pngBytes);
        final name = 'credencial_$safeFolio.pdf';
        final file = File('${tempDir.path}/$name');
        sharedFiles.add(file);
        await file.writeAsBytes(pdfBytes, flush: true);
        shared = XFile(file.path, mimeType: 'application/pdf', name: name);
      } else {
        final name = 'credencial_$safeFolio.png';
        final file = File('${tempDir.path}/$name');
        sharedFiles.add(file);
        await file.writeAsBytes(pngBytes, flush: true);
        shared = XFile(file.path, mimeType: 'image/png', name: name);
      }

      await SharePlus.instance.share(ShareParams(
        files: [shared],
        subject: 'virtual_card.share.subject'.tr(),
        text: 'virtual_card.share.text'.tr(namedArgs: {'folio': vm.folio}),
        sharePositionOrigin: sharePositionOrigin,
      ));
    } catch (e) {
      AppLogger.e('Error al compartir credencial',
          tag: 'VirtualCard', error: e);
      SacSnackBar.showMessenger(messenger, 'virtual_card.share_error'.tr(),
          isError: true);
    } finally {
      // The credential carries name, photo and QR: it does not stay in the
      // temp folder (FP-49). Grace period for apps that read it late.
      unawaited(
        deleteCredentialShareFiles(
          sharedFiles,
          grace: kCredentialShareCleanupGrace,
        ),
      );
      if (mounted) setState(() => _shareVm = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(virtualCardRateLimitNoticeProvider, (previous, next) {
      if (previous == null || next <= previous) return;
      SacSnackBar.show(context, 'virtual_card.errors.rate_limited'.tr(),
          duration: const Duration(seconds: 3));
    });

    final state = ref.watch(virtualCardProvider);
    final card = state.value;
    final shareVm = _shareVm;

    return SecureScreen(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SacTopBar(
          title: 'virtual_card.title'.tr(),
          frosted: true,
          actions: [
            if (card != null)
              SacPressable(
                listenOnly: true,
                child: IconButton(
                  key: _shareButtonKey,
                  enableFeedback: false,
                  tooltip: 'virtual_card.share.action'.tr(),
                  onPressed: _sharing
                      ? null
                      : () => _openShareSheet(
                            CredencialViewModel.fromVirtualCard(card),
                          ),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedShare08,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            // The printable card, drawn off screen only while sharing.
            if (shareVm != null)
              Positioned(
                left: -4000,
                top: 0,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: _ShareRender(
                        boundaryKey: _shareBoundaryKey, vm: shareVm),
                  ),
                ),
              ),
            SacFrostedVeil(
              child: Builder(
                builder: (context) => SafeArea(
                  top: false,
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    edgeOffset: SacTopBar.frostedInset(context),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: SacTopBar.paddingBelowBar(
                          context, const EdgeInsets.only(bottom: 28)),
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: state.when(
                            loading: () => const _CredentialSkeleton(
                              key: ValueKey('virtual-card-loading'),
                            ),
                            error: (error, _) => SacErrorState(
                              key: const ValueKey('virtual-card-error'),
                              title: 'virtual_card.load_error'.tr(),
                              message: virtualCardErrorMessageKey(error).tr(),
                              retryLabel: 'virtual_card.retry'.tr(),
                              onRetry: _refresh,
                            ),
                            data: (card) => _CredentialBody(
                              key: ValueKey('virtual-card-${card.userId}'),
                              card: card,
                              parallax: !_sharing,
                              onQrTap: _openQr,
                              onRenew: _refresh,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CredentialBody extends StatelessWidget {
  const _CredentialBody({
    super.key,
    required this.card,
    required this.parallax,
    required this.onQrTap,
    required this.onRenew,
  });

  final VirtualCard card;
  final bool parallax;
  final void Function(CredencialViewModel vm, String heroTag) onQrTap;
  final Future<void> Function() onRenew;

  @override
  Widget build(BuildContext context) {
    final vm = CredencialViewModel.fromVirtualCard(card);
    final qrState = credentialQrStateOf(card);
    final heroTag = 'virtual-card-qr-${card.userId}';
    final notice = _CredentialNotice.of(card);
    final VoidCallback? onTap = switch (qrState) {
      CredencialQrState.ready => () => onQrTap(vm, heroTag),
      CredencialQrState.expired => onRenew,
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: notice,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: CredentialParallax(
            enabled: parallax,
            child: CredencialCard(
              key: const Key('virtual-card-credential'),
              vm: vm,
              qrState: qrState,
              heroTag: heroTag,
              onQrTap: onTap,
            ),
          ),
        ),
        _CredentialDetails(vm: vm),
        const MasterHonorBadgeStrip(),
      ],
    );
  }
}

/// One panel above the card when something limits the QR: suspended, expired
/// or the saved copy shown without connection (in that order).
class _CredentialNotice extends StatelessWidget {
  const _CredentialNotice._({
    required this.kind,
    required this.icon,
    required this.titleKey,
    required this.messageKey,
    required this.warning,
  });

  final SacStatusKind kind;
  final HugeIconData icon;
  final String titleKey;
  final String messageKey;
  final bool warning;

  static _CredentialNotice? of(VirtualCard card) {
    if (card.isInactive) {
      return const _CredentialNotice._(
        kind: SacStatusKind.rejected,
        icon: HugeIcons.strokeRoundedSquareLock02,
        titleKey: 'virtual_card.states.suspended_title',
        messageKey: 'virtual_card.states.suspended_message',
        warning: false,
      );
    }
    if (card.hasQr && card.isExpired) {
      return const _CredentialNotice._(
        kind: SacStatusKind.pending,
        icon: HugeIcons.strokeRoundedClock01,
        titleKey: 'virtual_card.states.expired_title',
        messageKey: 'virtual_card.states.expired_message',
        warning: true,
      );
    }
    if (card.isOffline) {
      return const _CredentialNotice._(
        kind: SacStatusKind.review,
        icon: HugeIcons.strokeRoundedWifiOff01,
        titleKey: 'virtual_card.states.offline_title',
        messageKey: 'virtual_card.states.offline_message',
        warning: false,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final title = titleKey.tr();
    final base = SacStatusStyle.of(context, kind, label: title, icon: icon);
    final style = warning
        ? SacStatusStyle(
            kind: kind,
            container: c.warningContainer,
            onContainer: c.onWarningContainer,
            solid: c.warning,
            icon: icon,
            label: title,
          )
        : base;
    return SacStatePanel(
      key: Key('virtual-card-notice-$titleKey'),
      style: style,
      title: title,
      message: messageKey.tr(),
    );
  }
}

/// The data of the credential as label and value rows.
class _CredentialDetails extends StatelessWidget {
  const _CredentialDetails({required this.vm});

  final CredencialViewModel vm;

  static String _shown(String value) =>
      value.trim().isEmpty ? '—' : value.trim();

  @override
  Widget build(BuildContext context) {
    final blood = BloodType.localizedDisplayFor(
      vm.tipoSangre,
      languageCode: context.locale.languageCode,
    );
    final rows = <Widget>[
      SacSettingsValueTile(
        icon: HugeIcons.strokeRoundedUserGroup,
        label: 'virtual_card.field_club'.tr(),
        value: _shown(vm.club),
      ),
      SacSettingsValueTile(
        icon: HugeIcons.strokeRoundedLocation01,
        label: 'virtual_card.field_local_field'.tr(),
        value: _shown(vm.campoLocal),
      ),
      SacSettingsValueTile(
        icon: HugeIcons.strokeRoundedGlobe02,
        label: 'virtual_card.field_union'.tr(),
        value: _shown(vm.unionNombre),
      ),
      SacSettingsValueTile(
        icon: HugeIcons.strokeRoundedCalendar03,
        label: 'virtual_card.field_year'.tr(),
        value: _shown(vm.anioEclesiastico),
      ),
      if (blood != null && blood.isNotEmpty)
        SacSettingsValueTile(
          icon: HugeIcons.strokeRoundedBloodType,
          label: 'virtual_card.field_blood'.tr(),
          value: blood,
        ),
    ];
    return SacGroupedSection(
      label: 'virtual_card.details_title'.tr(),
      count: 0,
      action: const SizedBox.shrink(),
      dividerIndent: 42,
      children: rows,
    );
  }
}

/// The image that is shared: the card with its data rows, always in light
/// mode and at a fixed width so every phone shares the same artifact.
class _ShareRender extends StatelessWidget {
  const _ShareRender({required this.boundaryKey, required this.vm});

  final GlobalKey boundaryKey;
  final CredencialViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: RepaintBoundary(
        key: boundaryKey,
        child: Container(
          width: 360,
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: CredencialCard(vm: vm, showDetails: true),
        ),
      ),
    );
  }
}

class _CredentialSkeleton extends StatelessWidget {
  const _CredentialSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Semantics(
      label: 'virtual_card.loading'.tr(),
      child: SacShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius:
                      BorderRadius.circular(CredencialTokens.rImmersive),
                  border: Border.all(color: c.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: const Column(
                  children: [
                    SacSkeletonBox(height: 124, radius: 0),
                    SizedBox(height: 18),
                    SacSkeletonBox(width: 196, height: 196),
                    SizedBox(height: 12),
                    SacSkeletonBox(width: 220, height: 12),
                    SizedBox(height: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SacSkeletonBox(height: 160),
            ),
          ],
        ),
      ),
    );
  }
}

/// Options to share the credential: as an image or as a PDF.
Future<CredentialShareFormat?> showCredentialShareSheet(BuildContext context) {
  return showSacSheet<CredentialShareFormat>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SacSheetHeader(
            title: 'virtual_card.share.title'.tr(),
            subtitle: 'virtual_card.share.subtitle'.tr(),
          ),
          _ShareOption(
            key: const Key('virtual-card-share-image'),
            icon: HugeIcons.strokeRoundedImage01,
            title: 'virtual_card.share.image'.tr(),
            hint: 'virtual_card.share.image_hint'.tr(),
            onTap: () => Navigator.pop(ctx, CredentialShareFormat.image),
          ),
          _ShareOption(
            key: const Key('virtual-card-share-pdf'),
            icon: HugeIcons.strokeRoundedPdf01,
            title: 'virtual_card.share.pdf'.tr(),
            hint: 'virtual_card.share.pdf_hint'.tr(),
            onTap: () => Navigator.pop(ctx, CredentialShareFormat.pdf),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final HugeIconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);
    return SacPressable(
      listenOnly: true,
      child: ListTile(
        enableFeedback: false,
        minTileHeight: 60,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.light,
            borderRadius: BorderRadius.circular(AppTheme.radiusXS),
          ),
          child: Center(
            child: HugeIcon(icon: icon, size: 22, color: accent.color),
          ),
        ),
        title: Text(title),
        subtitle: Text(hint),
        onTap: onTap,
      ),
    );
  }
}

String virtualCardErrorMessageKey(Object error) {
  if (error is ConnectionException) {
    return 'common.error_network';
  }
  if (isVirtualCardRateLimit(error)) {
    return 'virtual_card.errors.rate_limited';
  }
  return 'virtual_card.errors.load_failed';
}
