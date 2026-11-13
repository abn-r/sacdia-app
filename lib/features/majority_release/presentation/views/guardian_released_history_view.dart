import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../domain/entities/released_entry.dart';
import '../majority_release_error_messages.dart';
import '../providers/majority_release_providers.dart';
import '../widgets/adult_claim_code_sheet.dart';

/// Historial de personas liberadas del ex tutor (`/family/released`, Fase 4).
///
/// Entrada mínima y de solo lectura: nombre (o «Persona liberada» si ya no
/// existe) y fecha. Sin salud, club, progreso ni contacto. Si la persona aún no
/// tiene credenciales, el ex tutor puede generar un código de acceso (sin
/// plazo); se muestra una sola vez.
class GuardianReleasedHistoryView extends ConsumerWidget {
  const GuardianReleasedHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final history = ref.watch(guardianReleasedHistoryProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'family.history.title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      body: history.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, _) => SacErrorState(
          title: majorityReleaseErrorMessage(error),
          onRetry: () => ref.invalidate(guardianReleasedHistoryProvider),
        ),
        data: (entries) => RefreshIndicator(
          color: SacAccent.of(context).color,
          onRefresh: () async {
            ref.invalidate(guardianReleasedHistoryProvider);
            await ref
                .read(guardianReleasedHistoryProvider.future)
                .catchError((_) => const <ReleasedEntry>[]);
          },
          child: entries.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 48),
                    SacEmptyState(
                      title: 'family.history.empty_title'.tr(),
                      body: 'family.history.empty_body'.tr(),
                      icon: HugeIcons.strokeRoundedUserGroup,
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    Responsive.horizontalPadding(context),
                    8,
                    Responsive.horizontalPadding(context),
                    32,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'family.history.intro'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: c.textSecondary, height: 1.4),
                      ),
                    ),
                    for (final entry in entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ReleasedEntryCard(
                          key: ValueKey(entry.guardianshipId),
                          entry: entry,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Una persona liberada: nombre y fecha, y (si aplica) «Generar código de
/// acceso».
class ReleasedEntryCard extends ConsumerStatefulWidget {
  const ReleasedEntryCard({super.key, required this.entry});

  final ReleasedEntry entry;

  @override
  ConsumerState<ReleasedEntryCard> createState() => _ReleasedEntryCardState();
}

class _ReleasedEntryCardState extends ConsumerState<ReleasedEntryCard> {
  bool _busy = false;

  String get _name =>
      widget.entry.displayName ?? 'family.history.released_person'.tr();

  Future<void> _generate() async {
    setState(() => _busy = true);
    final result = await ref
        .read(majorityReleaseRepositoryProvider)
        .issueGuardianCode(widget.entry.dependentUserId);
    if (!mounted) return;
    setState(() => _busy = false);
    await result.fold<Future<void>>(
      (failure) async => SacSnackBar.show(
        context,
        majorityReleaseErrorMessage(failure),
        isError: true,
      ),
      (issued) =>
          showAdultClaimCodeSheet(context, issued: issued, personName: _name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final entry = widget.entry;
    final date = entry.releasedAt;
    final dateText = date == null
        ? null
        : DateFormat.yMMMd(context.locale.toString()).format(date.toLocal());

    return SacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _name,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (entry.relationshipTypeName != null) ...[
            const SizedBox(height: 2),
            Text(
              entry.relationshipTypeName!,
              style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ],
          if (dateText != null) ...[
            const SizedBox(height: 6),
            Text(
              'family.history.released_on'.tr(namedArgs: {'date': dateText}),
              style: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
            ),
          ],
          if (entry.canIssueClaim) ...[
            const SizedBox(height: 12),
            SacButton.outline(
              key: const ValueKey('family_history_generate_code'),
              text: 'family.history.generate_code'.tr(),
              icon: HugeIcons.strokeRoundedKey01,
              isLoading: _busy,
              isEnabled: !_busy,
              onPressed: _generate,
            ),
          ],
        ],
      ),
    );
  }
}
