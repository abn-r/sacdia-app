import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_filter_chip.dart';
import '../../../../core/widgets/sac_list_row.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../../auth/domain/entities/authorization_snapshot.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../post_registration/presentation/providers/club_selection_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/transfer_club_option.dart';
import '../providers/transfer_providers.dart';
import '../widgets/club_type_tile.dart';
import '../widgets/transfer_sheets.dart';

/// "Elige tu nuevo club": clubs of the member's local field (or another one),
/// searchable by name or church. Clubs without the member's club type show,
/// disabled, with the reason. Choosing one opens the confirmation sheet.
class TransferClubPickerView extends ConsumerStatefulWidget {
  const TransferClubPickerView({super.key});

  @override
  ConsumerState<TransferClubPickerView> createState() =>
      _TransferClubPickerViewState();
}

class _TransferClubPickerViewState
    extends ConsumerState<TransferClubPickerView> {
  String _query = '';

  /// Another local field picked with "Otro campo"; null = the member's own.
  int? _otherFieldId;
  String? _otherFieldName;

  @override
  void initState() {
    super.initState();
    // A previous attempt may have left an error behind.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(createTransferProvider);
    });
  }

  Future<void> _pickOtherField() async {
    final source = ref.read(clubSelectionDataSourceProvider);
    final country = await showTransferPickSheet(
      context,
      title: 'transfers.picker.pick_country'.tr(),
      load: () async => [
        for (final x in await source.getCountries())
          TransferPickOption(x.id, x.name),
      ],
    );
    if (country == null || !mounted) return;
    final union = await showTransferPickSheet(
      context,
      title: 'transfers.picker.pick_union'.tr(),
      load: () async => [
        for (final x in await source.getUnionsByCountry(country.id))
          TransferPickOption(x.id, x.name),
      ],
    );
    if (union == null || !mounted) return;
    final field = await showTransferPickSheet(
      context,
      title: 'transfers.picker.pick_field'.tr(),
      load: () async => [
        for (final x in await source.getLocalFieldsByUnion(union.id))
          TransferPickOption(x.id, x.name),
      ],
    );
    if (field == null || !mounted) return;
    setState(() {
      _otherFieldId = field.id;
      _otherFieldName = field.name;
    });
  }

  Future<void> _choose(
    AuthorizationGrant grant,
    TransferClubOption club,
    String? currentClass,
  ) async {
    final type = grant.clubTypeName ?? '';
    final keeps = currentClass == null || currentClass.isEmpty
        ? type
        : 'transfers.confirm.keeps_class'
            .tr(namedArgs: {'type': type, 'class': currentClass});
    final sent = await showTransferConfirmSheet(
      context,
      fromClub: grant.clubName ?? '',
      toClub: club.name,
      keeps: keeps,
      fromSectionId: grant.sectionId!,
      toSectionId: club.sectionId!,
    );
    if (!sent || !mounted) return;
    SacSnackBar.show(
      context,
      'transfers.form.success_message'.tr(),
      isSuccess: true,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final grant = ref.watch(
      authNotifierProvider.select(
        (value) => value.value?.authorization?.activeGrant,
      ),
    );
    // Watched (not read) so the profile is loaded by the time a club is
    // chosen: the class goes into the summary.
    final currentClass =
        ref.watch(profileNotifierProvider).value?.currentClass?.trim();
    final typeId = grant?.clubTypeId;
    final fieldId = _otherFieldId ?? grant?.localFieldId;
    final fieldName =
        _otherFieldId != null ? _otherFieldName : grant?.localFieldName;

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'transfers.picker.title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      body: grant == null || typeId == null || grant.sectionId == null
          ? SacErrorState(
              title: 'transfers.form.no_active_membership'.tr(),
              onRetry: () => ref
                  .read(authNotifierProvider.notifier)
                  .refreshCurrentUser(keepCurrentOnFailure: true),
            )
          : ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(top: 4, bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: SacTextField(
                    key: const ValueKey('transfer-search'),
                    hint: 'transfers.picker.search_hint'.tr(),
                    prefixIcon: HugeIcons.strokeRoundedSearch01,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                    children: [
                      if (fieldName != null) ...[
                        SacFilterChip(
                          label: fieldName,
                          selected: true,
                        ),
                        const SizedBox(width: 8),
                      ],
                      SacFilterChip(
                        key: const ValueKey('transfer-other-field'),
                        label: 'transfers.picker.other_field'.tr(),
                        selected: false,
                        icon: HugeIcons.strokeRoundedLocation01,
                        onTap: _pickOtherField,
                      ),
                    ],
                  ),
                ),
                if (fieldId == null)
                  _Hint(text: 'transfers.picker.no_field'.tr())
                else
                  _ClubList(
                    grant: grant,
                    fieldId: fieldId,
                    typeId: typeId,
                    query: _query,
                    onChoose: (club) => _choose(grant, club, currentClass),
                  ),
              ],
            ),
    );
  }
}

class _ClubList extends ConsumerWidget {
  const _ClubList({
    required this.grant,
    required this.fieldId,
    required this.typeId,
    required this.query,
    required this.onChoose,
  });

  final AuthorizationGrant grant;
  final int fieldId;
  final int typeId;
  final String query;
  final ValueChanged<TransferClubOption> onChoose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = grant.clubTypeName ?? '';
    final clubsAsync = ref.watch(destinationClubsProvider((fieldId, typeId)));
    return clubsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: SacLoading()),
      ),
      error: (e, _) => SacErrorState(
        title: userErrorMessage(e),
        onRetry: () =>
            ref.invalidate(destinationClubsProvider((fieldId, typeId))),
      ),
      data: (all) {
        final clubs = filterDestinationClubs(
          all,
          query: query,
          excludeClubId: grant.clubId,
        );
        if (clubs.isEmpty) {
          return _Hint(text: 'transfers.picker.empty'.tr());
        }
        return SacGroupedSection(
          label: 'transfers.picker.clubs_with'.tr(namedArgs: {'type': type}),
          count: clubs.where((x) => x.isAvailable).length,
          children: [
            for (final club in clubs)
              SacListRow(
                key: ValueKey('transfer-club-${club.clubId}'),
                leading: ClubTypeTile(initials: clubInitials(club.name)),
                title: club.name,
                subtitle: club.isAvailable
                    ? club.churchName
                    : 'transfers.picker.no_section'
                        .tr(namedArgs: {'type': type}),
                enabled: club.isAvailable,
                showChevron: club.isAvailable,
                onTap: club.isAvailable ? () => onChoose(club) : null,
              ),
          ],
        );
      },
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: SacFontSize.bodyMedium,
          height: 1.4,
          color: context.sac.textSecondary,
        ),
      ),
    );
  }
}

/// Up to two initials of a club name ("Vega" → "VE", "Estrella del Mar" →
/// "EM").
String clubInitials(String name) {
  const skip = {'de', 'del', 'la', 'las', 'el', 'los', 'y'};
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && !skip.contains(w.toLowerCase()));
  final list = words.isEmpty ? [name.trim()] : words.toList();
  if (list.length == 1) {
    final w = list.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return (list[0][0] + list[1][0]).toUpperCase();
}

/// Clubs that match [query] by name or church (accents and case ignored),
/// without the member's own club; clubs that can take the member first.
List<TransferClubOption> filterDestinationClubs(
  List<TransferClubOption> clubs, {
  required String query,
  int? excludeClubId,
}) {
  final q = _fold(query.trim());
  final out = [
    for (final club in clubs)
      if (club.clubId != excludeClubId &&
          (q.isEmpty ||
              _fold(club.name).contains(q) ||
              _fold(club.churchName ?? '').contains(q)))
        club,
  ];
  out.sort((a, b) {
    if (a.isAvailable != b.isAvailable) return a.isAvailable ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return out;
}

String _fold(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áàä]'), 'a')
    .replaceAll(RegExp('[éèë]'), 'e')
    .replaceAll(RegExp('[íìï]'), 'i')
    .replaceAll(RegExp('[óòö]'), 'o')
    .replaceAll(RegExp('[úùü]'), 'u');
