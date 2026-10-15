import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/club_type.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';

import '../../domain/entities/certificate_import_class_option.dart';
import '../error/certificate_import_error_mapper.dart';
import '../providers/certificate_import_providers.dart';
import 'class_picker_list.dart';

/// Club type chips, the class list of that club type and the contextual
/// notices (class order, Guía Mayor). Owns no state: the editor does.
class ImportClassSection extends ConsumerWidget {
  const ImportClassSection({
    super.key,
    required this.clubTypeId,
    required this.classId,
    required this.onClubType,
    required this.onClass,
    this.classError,
    this.suggested = false,
  });

  final int? clubTypeId;
  final int? classId;
  final ValueChanged<int> onClubType;
  final ValueChanged<CertificateImportClassOption> onClass;
  final String? classError;

  /// The selected class came from the OCR and is not confirmed yet.
  final bool suggested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    final clubTypes = ref.watch(clubTypesProvider);
    final id = clubTypeId;

    Widget retry(Object error, VoidCallback onRetry) => ClassPickerError(
          message: CertificateImportErrorMapper.message(error),
          onRetry: onRetry,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'certificate_import.editor.club_type'.tr(),
          style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        clubTypes.when(
          loading: () => const Center(child: SacLoading()),
          error: (e, _) => retry(e, () => ref.invalidate(clubTypesProvider)),
          data: (types) => Wrap(
            spacing: 8,
            children: [
              for (final type in types)
                SacFilterChip(
                  label: type.name,
                  logoAsset: clubLogoAssetFromName(type.name),
                  selected: type.clubTypeId == id,
                  onTap: () => onClubType(type.clubTypeId),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (id == null)
          Text('certificate_import.editor.pick_club_type'.tr(),
              style: theme.bodySmall?.copyWith(color: c.textSecondary))
        else
          _classes(context, ref, id, retry),
      ],
    );
  }

  Widget _classes(
    BuildContext context,
    WidgetRef ref,
    int id,
    Widget Function(Object, VoidCallback) retry,
  ) {
    final theme = Theme.of(context).textTheme;
    final options = ref.watch(certificateImportClassCatalogProvider(id));
    return options.when(
      loading: () => ClassPickerList(
        options: null,
        selectedId: classId,
        onSelect: onClass,
      ),
      error: (e, _) => retry(
        e,
        () => ref.invalidate(certificateImportClassCatalogProvider(id)),
      ),
      data: (list) {
        final selected = list.where((o) => o.id == classId).firstOrNull;
        final hint = _orderHint(list, selected);
        final notice = _notice(selected);
        final style =
            theme.bodySmall?.copyWith(color: context.sac.textSecondary);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClassPickerList(
              options: list,
              selectedId: classId,
              onSelect: onClass,
              errorText: classError,
              suggestedId: suggested ? classId : null,
            ),
            for (final text in [
              if (hint != null) hint,
              if (notice != null) notice
            ])
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(text, style: style),
              ),
          ],
        );
      },
    );
  }

  /// "Puedes acreditar Explorador aunque no tengas Compañero registrado."
  /// Only when the chosen class has a previous one in its club type; the
  /// order is the catalog order and institutional classes do not count.
  static String? _orderHint(
    List<CertificateImportClassOption> list,
    CertificateImportClassOption? selected,
  ) {
    if (selected == null || selected.institutional) return null;
    final regular = list.where((o) => !o.institutional).toList();
    final index = regular.indexWhere((o) => o.id == selected.id);
    if (index < 1) return null;
    return 'certificate_import.editor.class_order_hint'.tr(namedArgs: {
      'class': selected.name,
      'previous': regular[index - 1].name,
    });
  }

  static String? _notice(CertificateImportClassOption? selected) {
    final code = (selected?.assetCode ?? '').toUpperCase();
    if (code == 'GM-01') return 'certificate_import.item.gm01_replace'.tr();
    if (selected != null &&
        (selected.institutional || code == 'GM-02' || code == 'GM-03')) {
      return 'certificate_import.item.institutional'.tr();
    }
    return null;
  }
}
