import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../widgets/member_qr_card.dart';

class MemberQrView extends StatelessWidget {
  const MemberQrView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('qr.my_credential'.tr()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MemberQrCard(),
              const SizedBox(height: 16),
              _InstructionsCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: Colors.black.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'qr.how_it_works'.tr(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• ${'qr.usage_tip_1'.tr()}\n'
              '• ${'qr.usage_tip_2'.tr()}\n'
              '• ${'qr.usage_tip_3'.tr()}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
