import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';

import '../../domain/entities/faq_item.dart';
import '../providers/support_providers.dart';
import '../widgets/faq_category_strip.dart';
import '../widgets/faq_item_card.dart';
import '../widgets/support_chrome.dart';

class FaqView extends ConsumerStatefulWidget {
  const FaqView({super.key});

  static const String routeName = '/settings/support/faq';

  @override
  ConsumerState<FaqView> createState() => _FaqViewState();
}

class _FaqViewState extends ConsumerState<FaqView> {
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'all';
  String? _expandedId;
  bool _entranceDone = false;

  @override
  void initState() {
    super.initState();
    final query = ref.read(faqSearchQueryProvider);
    if (query.isNotEmpty) {
      _searchCtrl.text = query;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _expandedId = null;
    });
    ref.read(faqSearchQueryProvider.notifier).state = value;
  }

  void _clearSearch() {
    setState(() {
      _searchCtrl.clear();
      _expandedId = null;
    });
    ref.read(faqSearchQueryProvider.notifier).state = '';
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(filteredFaqItemsProvider);
    final c = context.sac;
    final padding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: supportAppBar(context, title: 'support.faq_title'.tr()),
      body: filteredAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (e, _) => FaqErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(faqItemsProvider),
        ),
        data: (items) {
          final categories = _categoriesFrom(items);
          final visibleItems = _selectedCategory == 'all'
              ? items
              : items
                  .where((item) => item.category == _selectedCategory)
                  .toList(growable: false);

          if (!_entranceDone) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _entranceDone = true;
            });
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(
              padding,
              8,
              padding,
              28 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Semantics(
                textField: true,
                label: 'support.faq_search_hint'.tr(),
                child: SacTextField(
                  controller: _searchCtrl,
                  hint: 'support.faq_search_hint'.tr(),
                  prefixIcon: HugeIcons.strokeRoundedSearch01,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  suffix: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'common.clear'.tr(),
                          onPressed: _clearSearch,
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancelCircle,
                            size: 20,
                            color: c.textTertiary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              FaqCategoryStrip(
                categories: categories,
                selected: _selectedCategory,
                onSelected: (category) {
                  setState(() {
                    _selectedCategory = category;
                    _expandedId = null;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                'support.faq_count'.tr(args: ['${visibleItems.length}']),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: c.textTertiary,
                    ),
              ),
              const SizedBox(height: 12),
              if (visibleItems.isEmpty)
                FaqEmptyState(query: _searchCtrl.text)
              else
                ...visibleItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isExpanded = _expandedId == item.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: StaggeredListItem(
                      index: index,
                      staggerDelay: SacMotion.stagger,
                      duration: SacMotion.standard,
                      slideOffset: 8,
                      animate: !_entranceDone && index < 6,
                      child: FaqItemCard(
                        key: ValueKey(item.id),
                        item: item,
                        expanded: isExpanded,
                        onTap: () {
                          setState(() {
                            _expandedId = isExpanded ? null : item.id;
                          });
                        },
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  List<FaqCategoryFilter> _categoriesFrom(List<FaqItem> items) {
    final counts = <String, int>{'all': items.length};
    for (final item in items) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }

    const order = <String>[
      'all',
      'account',
      'onboarding',
      'offline',
      'notifications',
      'profile',
      'privacy',
      'support',
    ];

    return order
        .where(counts.containsKey)
        .map(
          (category) => FaqCategoryFilter(
            category: category,
            count: counts[category]!,
          ),
        )
        .toList(growable: false);
  }
}
