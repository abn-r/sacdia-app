import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/exceptions.dart';
import '../providers/virtual_card_providers.dart';
import '../widgets/credencial/action_pill.dart';
import '../widgets/credencial/credencial_card.dart';
import '../widgets/credencial/credencial_pdf.dart';
import '../widgets/credencial/credencial_qr_fullscreen.dart';
import '../widgets/credencial/credencial_tokens.dart';
import '../widgets/credencial/credencial_view_model.dart';
import '../widgets/virtual_card_skeleton.dart';
import 'virtual_card_photo_view.dart';

class VirtualCardView extends ConsumerStatefulWidget {
  const VirtualCardView({super.key});

  @override
  ConsumerState<VirtualCardView> createState() => _VirtualCardViewState();
}

class _VirtualCardViewState extends ConsumerState<VirtualCardView> {
  bool _downloadingPdf = false;

  Future<void> _refresh() async {
    ref.invalidate(virtualCardFetcherProvider);
    try {
      await ref.read(virtualCardFetcherProvider.future);
    } catch (_) {
      // Permitir que la UI muestre el error; el RefreshIndicator igual cierra.
    }
  }

  Future<void> _share(CredencialViewModel vm) async {
    await Share.share(
      'Mi credencial SACDIA\nFolio: ${vm.folio}\nClub: ${vm.club}',
      subject: 'Credencial Digital SACDIA',
    );
  }

  Future<void> _downloadAndSharePdf(CredencialViewModel vm) async {
    if (_downloadingPdf) return;
    setState(() => _downloadingPdf = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await buildCredencialPdf(vm);
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'credencial_${vm.folio.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('No se pudo generar el PDF: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
      ));
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Próximamente'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(virtualCardProvider);

    return Scaffold(
      appBar: AppBar(
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
                        Stack(
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
                                  icon: Icons.wifi_off_outlined,
                                  text: 'virtual_card.offline_banner'.tr(),
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
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ActionPill(
                                label: 'Wallet',
                                icon: ActionIcon.wallet,
                                primary: true,
                                onTap: () => _showComingSoon('Wallet'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ActionPill(
                                label: 'Compartir',
                                icon: ActionIcon.share,
                                onTap: () => _share(vm),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ActionPill(
                                label: _downloadingPdf ? 'Descargando…' : 'PDF',
                                icon: ActionIcon.pdf,
                                onTap: _downloadingPdf
                                    ? null
                                    : () => _downloadAndSharePdf(vm),
                              ),
                            ),
                          ],
                        ),
                        if (card.photoUrl?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => VirtualCardPhotoView(
                                    title: card.fullName,
                                    photoUrl: card.photoUrl,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.photo_outlined, size: 18),
                              label: Text('virtual_card.view_photo'.tr()),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
  const _StatusBanner({
    super.key,
    required this.icon,
    required this.text,
  });

  final IconData icon;
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
          Icon(icon, color: Colors.white, size: 16),
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
  return 'virtual_card.errors.load_failed';
}

Route<void> _credencialQrFullscreenRoute(
  CredencialViewModel vm,
  String heroTag,
) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => CredencialQrFullscreen(
      vm: vm,
      heroTag: heroTag,
    ),
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
