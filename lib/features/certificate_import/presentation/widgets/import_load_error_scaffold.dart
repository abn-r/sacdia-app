import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import 'certificate_import_back_button.dart';

/// Full screen shown when a batch cannot be loaded (state G): never prints the
/// raw error, only a fixed message with a retry.
class ImportLoadErrorScaffold extends StatelessWidget {
  const ImportLoadErrorScaffold({
    super.key,
    required this.title,
    required this.bodyKey,
    required this.fallbackLocation,
    required this.onRetry,
  });

  final String title;

  /// Translation key of the body copy.
  final String bodyKey;
  final String fallbackLocation;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SacTopBar(
        title: title,
        leading:
            CertificateImportBackButton(fallbackLocation: fallbackLocation),
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => Padding(
            padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
            child: SacEmptyState(
              icon: HugeIcons.strokeRoundedAlert02,
              title: 'certificate_import.errors.load_error_title'.tr(),
              body: bodyKey.tr(),
              actionLabel: 'certificate_import.errors.retry'.tr(),
              actionIcon: HugeIcons.strokeRoundedRefresh,
              onAction: onRetry,
            ),
          ),
        ),
      ),
    );
  }
}
