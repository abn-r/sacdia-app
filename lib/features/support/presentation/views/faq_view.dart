import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/faq_item.dart';
import '../providers/support_providers.dart';
import '../widgets/faq_category_strip.dart';
import '../widgets/faq_question_row.dart';

/// Every question, grouped under its category once; each opens in place.
class FaqView extends ConsumerStatefulWidget {
  const FaqView({super.key});

  static const String routeName = '/settings/support/faq';

  /// Order of the categories in the chips and the groups.
  static const categoryOrder = <String>[
    'account',
    'onboarding',
    'offline',
    'notifications',
    'profile',
    'privacy',
    'support',
  ];

  @override
  ConsumerState<FaqView> createState() => _FaqViewState();
}

class _FaqViewState extends ConsumerState<FaqView> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedCategory = 'all';
  String? _expandedId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final itemsAsync = ref.watch(faqItemsProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'support.faq_title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (e, _) => SacErrorState(
          title: 'support.errors.faq_load_failed'.tr(),
          message: userErrorMessage(e),
          onRetry: () => ref.invalidate(faqItemsProvider),
        ),
        data: (all) {
          final query = _query.trim();
          final matching = [
            for (final i in all)
              if (i.matches(query)) i,
          ];
          final groups = groupFaqByCategory(matching);
          final visible = _selectedCategory == 'all'
              ? groups
              : {
                  for (final e in groups.entries)
                    if (e.key == _selectedCategory) e.key: e.value,
                };
          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(top: 4, bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: SacTextField(
                  key: const ValueKey('faq-search'),
                  controller: _searchCtrl,
                  hint: 'support.faq_search_hint'.tr(),
                  prefixIcon: HugeIcons.strokeRoundedSearch01,
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => setState(() {
                    _query = v;
                    _expandedId = null;
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: FaqCategoryStrip(
                  categories: [
                    FaqCategoryFilter(category: 'all', count: matching.length),
                    for (final e in groups.entries)
                      FaqCategoryFilter(category: e.key, count: e.value.length),
                  ],
                  selected: _selectedCategory,
                  onSelected: (category) => setState(() {
                    _selectedCategory = category;
                    _expandedId = null;
                  }),
                ),
              ),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Text(
                    query.isEmpty
                        ? 'support.faq_empty'.tr()
                        : 'support.faq_no_results'.tr(args: [query]),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              for (final e in visible.entries)
                SacGroupedSection(
                  key: ValueKey('faq-group-${e.key}'),
                  label: 'support.faq_category.${e.key}'.tr(),
                  dividerIndent: 16,
                  children: [
                    for (final item in e.value)
                      FaqQuestionRow(
                        key: ValueKey('faq-${item.id}'),
                        item: item,
                        expanded: _expandedId == item.id,
                        onTap: () => setState(
                          () => _expandedId =
                              _expandedId == item.id ? null : item.id,
                        ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// [items] by category, in [FaqView.categoryOrder]; unknown categories last.
Map<String, List<FaqItem>> groupFaqByCategory(List<FaqItem> items) {
  final byCategory = <String, List<FaqItem>>{};
  for (final item in items) {
    byCategory.putIfAbsent(item.category, () => []).add(item);
  }
  final ordered = <String, List<FaqItem>>{};
  for (final category in FaqView.categoryOrder) {
    final list = byCategory.remove(category);
    if (list != null) ordered[category] = list;
  }
  ordered.addAll(byCategory);
  return ordered;
}
