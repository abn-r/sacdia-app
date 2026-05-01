import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/qr_member_token_provider.dart';

class MemberQrCard extends ConsumerWidget {
  const MemberQrCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenAsync = ref.watch(qrMemberTokenProvider);
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedQrCode,
                  color: Colors.black87,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'qr.my_credential'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'qr.rotate_token'.tr(),
                  onPressed: tokenAsync.isLoading
                      ? null
                      : () => ref
                          .read(qrMemberTokenProvider.notifier)
                          .refresh(),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    color: Colors.black87,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: _QrBody(),
            ),
            const SizedBox(height: 12),
            _ExpiryFooter(),
          ],
        ),
      ),
    );
  }
}

class _QrBody extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(qrMemberTokenProvider);
    return state.when(
      data: (token) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: QrImageView(
          data: token.token,
          version: QrVersions.auto,
          backgroundColor: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                color: Colors.red,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'qr.generation_error_title'.tr(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                err.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(qrMemberTokenProvider.notifier).refresh(),
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpiryFooter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(qrMemberTokenProvider);
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.black54,
        );

    return state.maybeWhen(
      data: (token) {
        final remaining = token.expiresAt.difference(DateTime.now().toUtc());
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes.remainder(60);
        final label = remaining.isNegative
            ? 'qr.expired'.tr()
            : hours > 0
                ? 'qr.expires_in_hours_minutes'.tr(namedArgs: {
                    'hours': '$hours',
                    'minutes': '$minutes',
                  })
                : 'qr.expires_in_minutes'
                    .tr(namedArgs: {'minutes': '$minutes'});
        return Text(label, style: style);
      },
      orElse: () => Text('qr.idle_hint'.tr(), style: style),
    );
  }
}
