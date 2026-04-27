import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/errors/exceptions.dart';
import '../providers/virtual_card_providers.dart';
import '../widgets/virtual_card_face.dart';
import '../widgets/virtual_card_skeleton.dart';
import 'virtual_card_photo_view.dart';
import 'virtual_card_qr_fullscreen_view.dart';

class VirtualCardView extends ConsumerStatefulWidget {
  const VirtualCardView({super.key});

  @override
  ConsumerState<VirtualCardView> createState() => _VirtualCardViewState();
}

class _VirtualCardViewState extends ConsumerState<VirtualCardView> {
  Future<void> _refresh() async {
    ref.invalidate(virtualCardFetcherProvider);
    try {
      await ref.read(virtualCardFetcherProvider.future);
    } catch (_) {
      // Let the UI render the error state; refresh indicators should still stop.
    }
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final cardWidth = (maxWidth * 0.9).clamp(0.0, 360.0);

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  Center(
                    child: SizedBox(
                      width: cardWidth,
                      child: AnimatedSwitcher(
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
                          data: (card) => AspectRatio(
                            key: ValueKey('virtual-card-${card.userId}'),
                            aspectRatio: 5 / 8,
                            child: VirtualCardFace(
                              card: card,
                              onShowQr: card.canShowQr
                                  ? () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              VirtualCardQrFullscreenView(
                                            card: card,
                                          ),
                                        ),
                                      )
                                  : _refresh,
                              onPhotoTap: card.photoUrl?.trim().isNotEmpty == true
                                  ? () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => VirtualCardPhotoView(
                                            title: card.fullName,
                                            photoUrl: card.photoUrl,
                                          ),
                                        ),
                                      )
                                  : _refresh,
                              onRefresh: _refresh,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
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

String virtualCardErrorMessageKey(Object error) {
  if (error is ConnectionException) {
    return 'common.error_network';
  }

  return 'virtual_card.errors.load_failed';
}
