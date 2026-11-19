import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/in_app_browser.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/zarza_roja_credit.dart';

import '../providers/app_version_provider.dart';
import '../widgets/sync_cache_section.dart';

/// "Acerca de SACDIA": version, legal documents, the sync/cache tools and the
/// Zarza Roja credit.
class AboutView extends ConsumerWidget {
  const AboutView({super.key});

  Future<void> _openLegalDocument(BuildContext context, String url) async {
    final opened = await openInAppDocument(Uri.parse(url));
    if (!opened && context.mounted) {
      SacSnackBar.show(context, 'settings.open_document_failed'.tr());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final info = ref.watch(appPackageInfoProvider).value;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'settings.about_title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            final bar = SacTopBar.frostedInset(context);
            return ListView(
              padding: EdgeInsets.fromLTRB(16, bar + 8, 16, 8),
              children: [
                SacSettingsGroup(
                  children: [
                    SacSettingsTile(
                      icon: HugeIcons.strokeRoundedInformationCircle,
                      title: 'profile.settings.about_version'.tr(),
                      value: formatAppVersion(info),
                    ),
                    const SacSettingsDivider(),
                    SacSettingsTile(
                      icon: HugeIcons.strokeRoundedSecurityCheck,
                      title: 'profile.settings.privacy_policy'.tr(),
                      onTap: () => _openLegalDocument(
                        context,
                        AppConstants.privacyPolicyUrl,
                      ),
                    ),
                    const SacSettingsDivider(),
                    SacSettingsTile(
                      icon: HugeIcons.strokeRoundedLegalDocument01,
                      title: 'profile.settings.terms'.tr(),
                      onTap: () =>
                          _openLegalDocument(context, AppConstants.termsUrl),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const SyncCacheSection(),
                const SizedBox(height: 32),
                const ZarzaRojaCredit(),
                SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ],
            );
          },
        ),
      ),
    );
  }
}
