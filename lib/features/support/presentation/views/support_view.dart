import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_list_row.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/faq_item.dart';
import '../providers/support_providers.dart';
import '../support_contact.dart';
import '../widgets/faq_question_row.dart';
import 'faq_view.dart';
import 'report_problem_view.dart';

/// "Ayuda y soporte": the common questions, a search that filters them in
/// place and, below, how to reach support.
class SupportView extends ConsumerStatefulWidget {
  const SupportView({super.key});

  static const String routeName = '/settings/support';

  @override
  ConsumerState<SupportView> createState() => _SupportViewState();
}

class _SupportViewState extends ConsumerState<SupportView> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _expandedId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggle(FaqItem item) => setState(
        () => _expandedId = _expandedId == item.id ? null : item.id,
      );

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final items = ref.watch(faqItemsProvider).value ?? const <FaqItem>[];
    final query = _query.trim();
    final results = query.isEmpty
        ? const <FaqItem>[]
        : [
            for (final i in items)
              if (i.matches(query)) i,
          ];
    final featured = [
      for (final i in items)
        if (i.featured) i,
    ];

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'support.title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(top: 4, bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: SacTextField(
              key: const ValueKey('support-search'),
              controller: _searchCtrl,
              hint: 'support.hub_search_hint'.tr(),
              prefixIcon: HugeIcons.strokeRoundedSearch01,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() {
                _query = v;
                _expandedId = null;
              }),
              suffix: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'common.clear'.tr(),
                      onPressed: () => setState(() {
                        _searchCtrl.clear();
                        _query = '';
                        _expandedId = null;
                      }),
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancelCircle,
                        size: 20,
                        color: c.textTertiary,
                      ),
                    ),
            ),
          ),
          if (query.isNotEmpty)
            results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Text(
                      'support.faq_no_results'.tr(args: [query]),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        color: c.textSecondary,
                      ),
                    ),
                  )
                : SacGroupedSection(
                    label: 'support.search_results'.plural(results.length),
                    action: const SizedBox.shrink(),
                    dividerIndent: 16,
                    children: [
                      for (final item in results)
                        FaqQuestionRow(
                          key: ValueKey('support-result-${item.id}'),
                          item: item,
                          showCategory: true,
                          expanded: _expandedId == item.id,
                          onTap: () => _toggle(item),
                        ),
                    ],
                  )
          else if (featured.isNotEmpty)
            SacGroupedSection(
              label: 'support.faq_title'.tr(),
              dividerIndent: 16,
              action: _SeeAll(count: items.length),
              children: [
                for (final item in featured)
                  FaqQuestionRow(
                    key: ValueKey('support-featured-${item.id}'),
                    item: item,
                    expanded: _expandedId == item.id,
                    onTap: () => _toggle(item),
                  ),
              ],
            ),
          SacGroupedSection(
            label: 'support.more_help'.tr(),
            action: const SizedBox.shrink(),
            dividerIndent: 62,
            children: [
              SacListRow(
                key: const ValueKey('support-write'),
                leading: const SacListRowIcon(HugeIcons.strokeRoundedMail01),
                title: 'support.write_title'.tr(),
                subtitle: 'support.contact_hours_short'.tr(),
                onTap: () => openSupportEmail(context),
                showChevron: false,
                trailing: IconButton(
                  key: const ValueKey('support-copy-email'),
                  tooltip: 'support.contact_copy'.tr(),
                  onPressed: () => copySupportEmail(context),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCopy01,
                    size: 20,
                    color: SacAccent.of(context).color,
                  ),
                ),
              ),
              SacListRow(
                key: const ValueKey('support-report'),
                leading: const SacListRowIcon(HugeIcons.strokeRoundedBug01),
                title: 'support.report_tile'.tr(),
                subtitle: 'support.report_row_subtitle'.tr(),
                onTap: () => context.push(ReportProblemView.routeName),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Ver las 15": the whole list, by category.
class _SeeAll extends StatelessWidget {
  const _SeeAll({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const ValueKey('support-see-all'),
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => context.push(FaqView.routeName),
      child: Text(
        'support.see_all'.tr(namedArgs: {'count': '$count'}),
        style: TextStyle(
          fontSize: SacFontSize.bodyMedium,
          fontWeight: FontWeight.w600,
          color: SacAccent.of(context).color,
        ),
      ),
    );
  }
}
