import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/secure_screen.dart';
import '../providers/virtual_card_providers.dart';
import '../widgets/credencial/action_pill.dart';
import '../widgets/credencial/credencial_card.dart';
import '../widgets/credencial/credencial_qr_fullscreen.dart';
import '../widgets/credencial/credencial_tokens.dart';
import '../widgets/credencial/credencial_view_model.dart';
import '../widgets/credencial/credential_parallax.dart';
import '../widgets/virtual_card_skeleton.dart';
import '../utils/credential_image_pdf.dart';
import '../utils/credential_share_capture.dart';
import '../utils/share_position_origin.dart';
import '../../../master_honors/presentation/widgets/master_honor_history_section.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';

class VirtualCardView extends ConsumerStatefulWidget {
  const VirtualCardView({super.key});

  @override
  ConsumerState<VirtualCardView> createState() => _VirtualCardViewState();
}

class _VirtualCardViewState extends ConsumerState<VirtualCardView> {
  final GlobalKey _cardBoundaryKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();
  bool _sharingCredential = false;

  Future<void> _refresh() async {
    ref.invalidate(virtualCardFetcherProvider);
    try {
      await ref.read(virtualCardFetcherProvider.future);
    } catch (_) {
      // Permitir que la UI muestre el error; el RefreshIndicator igual cierra.
    }
  }

  Future<void> _shareCredential(CredencialViewModel vm) async {
    if (_sharingCredential) return;
    setState(() => _sharingCredential = true);
    final messenger = ScaffoldMessenger.of(context);
    final sharePositionOrigin = sharePositionOriginForContext(
      _shareButtonKey.currentContext ?? context,
    );
    try {
      final pngBytes = await captureCredentialBoundaryPng(
        boundaryKey: _cardBoundaryKey,
        viewContext: context,
      );
      final pdfBytes = await buildCredentialImagePdf(pngBytes);

      final safeFolio = vm.folio.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final pngFileName = 'credencial_$safeFolio.png';
      final pdfFileName = 'credencial_$safeFolio.pdf';
      final tempDir = await getTemporaryDirectory();
      final pngFile = File('${tempDir.path}/$pngFileName');
      final pdfFile = File('${tempDir.path}/$pdfFileName');
      await pngFile.writeAsBytes(pngBytes, flush: true);
      await pdfFile.writeAsBytes(pdfBytes, flush: true);

      await Share.shareXFiles(
        [
          XFile(pngFile.path, mimeType: 'image/png', name: pngFileName),
          XFile(pdfFile.path, mimeType: 'application/pdf', name: pdfFileName),
        ],
        subject: 'Credencial Digital SACDIA',
        text: 'Mi credencial SACDIA · ${vm.folio}',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      AppLogger.e('Error al compartir credencial',
          tag: 'VirtualCard', error: e);
      messenger.showSnackBar(
        SnackBar(
          content: Text('virtual_card.share_error'.tr()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharingCredential = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(virtualCardRateLimitNoticeProvider, (previous, next) {
      if (previous == null || next <= previous) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('virtual_card.errors.rate_limited'.tr()),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    });

    final state = ref.watch(virtualCardProvider);

    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: sacAutoBackButton(context),
          title: Text('virtual_card.title'.tr()),
          actions: [
            IconButton(
              tooltip: 'virtual_card.refresh'.tr(),
              onPressed: _refresh,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                size: 22,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: state.when(
                    loading: () => const AspectRatio(
                      key: ValueKey('virtual-card-loading'),
                      aspectRatio: 5 / 8,
                      child: VirtualCardSkeleton(),
                    ),
                    error: (error, _) => _ErrorState(
                      key: const ValueKey('virtual-card-error'),
                      messageKey: virtualCardErrorMessageKey(error),
                      onRetry: _refresh,
                    ),
                    data: (card) {
                      final vm = CredencialViewModel.fromVirtualCard(card);
                      final heroTag = 'virtual-card-qr-${card.userId}';
                      return Column(
                        key: ValueKey('virtual-card-${card.userId}'),
                        children: [
                          CredentialParallax(
                            enabled: !_sharingCredential,
                            child: RepaintBoundary(
                              key: _cardBoundaryKey,
                              child: Stack(
                                children: [
                                  CredencialCard(
                                    vm: vm,
                                    onQrTap: card.canShowQr
                                        ? () => Navigator.of(context).push(
                                              _credencialQrFullscreenRoute(
                                                vm,
                                                heroTag,
                                              ),
                                            )
                                        : _refresh,
                                  ),
                                  if (card.isOffline)
                                    Positioned(
                                      top: 14,
                                      left: 14,
                                      right: 14,
                                      child: _StatusBanner(
                                        key: const Key(
                                          'virtual-card-offline-banner',
                                        ),
                                        icon: HugeIcons.strokeRoundedWifiOff01,
                                        text:
                                            'virtual_card.offline_banner'.tr(),
                                      ),
                                    ),
                                  if (card.isInactive)
                                    Positioned.fill(
                                      child: Container(
                                        key: const Key(
                                          'virtual-card-inactive-overlay',
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0x33C53D3D),
                                          borderRadius: BorderRadius.circular(
                                            CredencialTokens.rImmersive,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.all(24),
                                        child: Text(
                                          'virtual_card.inactive_message'.tr(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            key: _shareButtonKey,
                            width: double.infinity,
                            child: ActionPill(
                              label: _sharingCredential
                                  ? 'virtual_card.share_preparing'.tr()
                                  : 'virtual_card.share_card'.tr(),
                              icon: ActionIcon.share,
                              primary: true,
                              onTap: _sharingCredential
                                  ? null
                                  : () => _shareCredential(vm),
                            ),
                          ),
                          const MasterHonorBadgeStrip(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    super.key,
    required this.messageKey,
    required this.onRetry,
  });

  final String messageKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 52,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 16),
          Text(
            'virtual_card.load_error'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            messageKey.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onRetry,
            child: Text('virtual_card.retry'.tr()),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({super.key, required this.icon, required this.text});

  final HugeIconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xEE0F1B2D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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

Route<void> _credencialQrFullscreenRoute(
  CredencialViewModel vm,
  String heroTag,
) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) =>
        CredencialQrFullscreen(vm: vm, heroTag: heroTag),
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}
