import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_map_options_sheet.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../domain/entities/club_info.dart';
import '../providers/club_providers.dart';
import '../widgets/club_profile_widgets.dart';
import 'club_edit_view.dart';

/// Mi club: the club's ficha, read-only for everyone.
///
/// Members see only the data that exists. Directors (`canEditClubProvider`)
/// also see «Sin registrar» rows, a prompt with the missing fields and an
/// «Editar» action that opens [ClubEditView]. Route: /home/club
class ClubView extends ConsumerWidget {
  const ClubView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final sectionAsync = ref.watch(currentClubSectionProvider);
    final canEdit = ref.watch(canEditClubProvider).value ?? false;
    final section = sectionAsync.value;
    final clubId = section?.mainClubId ?? '';
    final club =
        clubId.isEmpty ? null : ref.watch(clubInfoProvider(clubId)).value;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'club.my_club_title'.tr(),
        frosted: true,
        actions: [
          if (canEdit && section != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                key: const ValueKey('club-edit-action'),
                onPressed: () => _openEditor(context, section, club),
                style: TextButton.styleFrom(
                  foregroundColor: SacAccent.of(context).color,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  textStyle: const TextStyle(
                    fontSize: SacFontSize.titleMedium,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text('common.edit'.tr()),
              ),
            ),
        ],
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => sectionAsync.when(
            loading: () => const Center(child: SacLoading()),
            error: (error, _) => SacErrorState(
              title: 'club.load_error'.tr(),
              message: userErrorMessage(error),
              onRetry: () => ref.invalidate(currentClubSectionProvider),
            ),
            data: (section) {
              if (section == null) {
                return SacEmptyState(
                  icon: HugeIcons.strokeRoundedBackpack03,
                  title: 'club.no_club_assigned'.tr(),
                  body: 'club.no_club_description'.tr(),
                );
              }
              return RefreshIndicator(
                edgeOffset: SacTopBar.frostedInset(context),
                onRefresh: () async {
                  ref.invalidate(currentClubSectionProvider);
                  try {
                    await ref.read(currentClubSectionProvider.future);
                  } catch (_) {
                    // The error stays in the provider and the view shows it.
                  }
                },
                child: _ClubProfileBody(
                  section: section.withClubLocation(club),
                  clubName: club?.name.trim() ?? '',
                  canEdit: canEdit,
                  onEdit: () => _openEditor(context, section, club),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static Future<void> _openEditor(
    BuildContext context,
    ClubSection section,
    ClubInfo? club,
  ) async {
    HapticFeedback.lightImpact();
    final saved = await showClubEditView(
      context,
      section,
      clubLat: club?.lat,
      clubLong: club?.long,
    );
    if (saved && context.mounted) {
      SacSnackBar.show(context, 'club.update_success'.tr(), isSuccess: true);
    }
  }
}

class _ClubProfileBody extends StatelessWidget {
  const _ClubProfileBody({
    required this.section,
    required this.clubName,
    required this.canEdit,
    required this.onEdit,
  });

  final ClubSection section;
  final String clubName;
  final bool canEdit;
  final VoidCallback onEdit;

  Future<void> _launch(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!opened && context.mounted) {
      SacSnackBar.show(context, 'club.profile.open_failed'.tr(), isError: true);
    }
  }

  void _openMaps(BuildContext context) {
    showSacMapOptions(
      context,
      title: 'club.profile.directions'.tr(),
      errorMessage: 'activities.widgets.map_open_error'.tr(),
      place: section.address,
      lat: section.lat,
      lng: section.long,
    );
  }

  Uri _websiteUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return uri;
    return Uri.parse('https://$value');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final missing = section.missingFields;
    final phone = section.phoneValue;
    final email = section.emailValue;
    final website = section.websiteValue;
    final address = section.address?.trim() ?? '';

    final showLocation = canEdit || section.hasLocation;
    final contactRows = <Widget>[
      if (phone != null || canEdit)
        ClubInfoRow(
          key: const ValueKey('club-row-phone'),
          icon: HugeIcons.strokeRoundedCall,
          label: 'club.phone'.tr(),
          value: phone,
          actionHint: 'club.profile.call'.tr(),
          onTap: phone == null
              ? onEdit
              : () => _launch(
                    context,
                    Uri(
                        scheme: 'tel',
                        path: phone.replaceAll(RegExp(r'[^\d+]'), '')),
                  ),
        ),
      if (email != null || canEdit)
        ClubInfoRow(
          key: const ValueKey('club-row-email'),
          icon: HugeIcons.strokeRoundedMail01,
          label: 'club.email'.tr(),
          value: email,
          actionHint: 'club.profile.write'.tr(),
          onTap: email == null
              ? onEdit
              : () => _launch(context, Uri(scheme: 'mailto', path: email)),
        ),
      if (website != null || canEdit)
        ClubInfoRow(
          key: const ValueKey('club-row-website'),
          icon: HugeIcons.strokeRoundedGlobe02,
          label: 'club.website'.tr(),
          value: website,
          actionHint: 'club.profile.open_site'.tr(),
          onTap: website == null
              ? onEdit
              : () => _launch(context, _websiteUri(website)),
        ),
    ];

    final blocks = <Widget>[
      ClubProfileHero(
        name: clubName,
        clubTypeName: section.clubTypeName,
        logoUrl: section.logoValue,
      ),
      if (canEdit && missing.isNotEmpty)
        ClubMissingDataPrompt(
          missingCount: missing.length,
          onComplete: onEdit,
        ),
      if (showLocation)
        ClubInfoGroup(
          key: const ValueKey('club-group-location'),
          label: 'club.section.location'.tr(),
          header: section.hasCoordinates
              ? ClubMapPreview(
                  lat: section.lat!,
                  long: section.long!,
                  onTap: () => _openMaps(context),
                )
              : null,
          children: [
            ClubInfoRow(
              key: const ValueKey('club-row-address'),
              icon: HugeIcons.strokeRoundedLocation01,
              label: 'club.address'.tr(),
              value: section.hasLocation
                  ? (address.isNotEmpty
                      ? address
                      : 'club.profile.pinned_on_map'.tr())
                  : null,
              trailingIcon: HugeIcons.strokeRoundedDirections01,
              actionHint: 'club.profile.directions'.tr(),
              onTap: section.hasLocation ? () => _openMaps(context) : onEdit,
            ),
          ],
        ),
      if (contactRows.isNotEmpty)
        ClubInfoGroup(
          key: const ValueKey('club-group-contact'),
          label: 'club.section.contact'.tr(),
          children: contactRows,
        ),
      if (!showLocation && contactRows.isEmpty)
        Text(
          'club.profile.no_public_data'.tr(),
          key: const ValueKey('club-no-public-data'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: SacFontSize.bodyMedium,
            color: c.textSecondary,
          ),
        ),
    ];

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: SacTopBar.paddingBelowBar(
        context,
        const EdgeInsets.fromLTRB(20, 12, 20, 40),
      ),
      itemCount: blocks.length,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 28 : 24),
      itemBuilder: (_, index) => StaggeredListItem(
        index: index,
        staggerDelay: SacMotion.stagger,
        duration: SacMotion.standard,
        slideOffset: 8,
        child: blocks[index],
      ),
    );
  }
}
