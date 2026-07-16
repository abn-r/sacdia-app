import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_back_button.dart';
import '../../../../core/widgets/fixed_input_icon_slot.dart';
import '../../domain/entities/faq_item.dart';
import '../providers/support_providers.dart';

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(filteredFaqItemsProvider);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.surfaceVariant,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        title: Text('support.faq_title'.tr()),
        backgroundColor: c.surfaceVariant,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: filteredAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => _FaqError(message: e.toString()),
        data: (items) {
          final categories = _categoriesFrom(items);
          final visibleItems = _selectedCategory == 'all'
              ? items
              : items
                  .where((item) => item.category == _selectedCategory)
                  .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _FaqHero(totalItems: items.length),
              const SizedBox(height: 16),
              _FaqSearchField(
                controller: _searchCtrl,
                hint: 'support.faq_search_hint'.tr(),
                onChanged: (value) {
                  setState(() {});
                  ref.read(faqSearchQueryProvider.notifier).state = value;
                },
                onClear: () {
                  setState(() => _searchCtrl.clear());
                  ref.read(faqSearchQueryProvider.notifier).state = '';
                  FocusScope.of(context).unfocus();
                },
              ),
              const SizedBox(height: 14),
              _FaqCategoryStrip(
                categories: categories,
                selected: _selectedCategory,
                onSelected: (category) {
                  setState(() {
                    _selectedCategory = category;
                    _expandedId = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (visibleItems.isEmpty)
                _FaqEmpty(query: _searchCtrl.text)
              else
                ...visibleItems.map((item) {
                  final isExpanded = _expandedId == item.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FaqTrailCard(
                      item: item,
                      expanded: isExpanded,
                      onTap: () {
                        setState(() {
                          _expandedId = isExpanded ? null : item.id;
                        });
                      },
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  List<_FaqCategoryFilter> _categoriesFrom(List<FaqItem> items) {
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
        .where((category) => counts.containsKey(category))
        .map(
          (category) => _FaqCategoryFilter(
            category: category,
            count: counts[category]!,
          ),
        )
        .toList(growable: false);
  }
}

class _FaqCategoryFilter {
  const _FaqCategoryFilter({
    required this.category,
    required this.count,
  });

  final String category;
  final int count;
}

class _FaqHero extends StatelessWidget {
  const _FaqHero({required this.totalItems});

  final int totalItems;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.sac.border),
        boxShadow: [
          BoxShadow(
            color: context.sac.shadow.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCamper,
                color: AppColors.primary,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _faqCopy(context, 'support.faq_hero_title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.sac.text,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  _faqHeroBody(context, totalItems),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.sac.textSecondary,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqSearchField extends StatelessWidget {
  const _FaqSearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: c.shadow.withValues(alpha: 0.03),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: c.text,
              fontWeight: FontWeight.w600,
            ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: c.textTertiary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide:
                BorderSide(color: AppColors.primary.withValues(alpha: 0.28)),
          ),
          filled: true,
          fillColor: c.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          prefixIconConstraints: FixedInputIconSlot.constraints,
          prefixIcon: FixedInputIconSlot(
            icon: HugeIcons.strokeRoundedSearch01,
            color: c.textSecondary,
            iconSize: 24,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    color: c.textSecondary,
                    size: 20,
                  ),
                  onPressed: onClear,
                ),
        ),
      ),
    );
  }
}

class _FaqCategoryStrip extends StatelessWidget {
  const _FaqCategoryStrip({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<_FaqCategoryFilter> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = categories[index];
          final category = filter.category;
          final isSelected = category == selected;
          return ChoiceChip(
            selected: isSelected,
            showCheckmark: false,
            label: Text('${_categoryLabel(category)} (${filter.count})'),
            avatar: HugeIcon(
              icon: _categoryIcon(category),
              size: 16,
              color: isSelected ? Colors.white : context.sac.textSecondary,
            ),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : context.sac.text,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            selectedColor: AppColors.primary,
            backgroundColor: context.sac.surface,
            side: BorderSide(color: context.sac.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            onSelected: (_) => onSelected(category),
          );
        },
      ),
    );
  }
}

class _FaqTrailCard extends StatefulWidget {
  const _FaqTrailCard({
    required this.item,
    required this.expanded,
    required this.onTap,
  });

  final FaqItem item;
  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_FaqTrailCard> createState() => _FaqTrailCardState();
}

class _FaqTrailCardState extends State<_FaqTrailCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      scale: _pressed ? 0.985 : 1,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.expanded
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : c.border,
            ),
            boxShadow: [
              BoxShadow(
                color: c.shadow.withValues(alpha: 0.03),
                blurRadius: widget.expanded ? 8 : 7,
                offset: Offset(0, widget.expanded ? 3 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedQuestion,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item.question,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: c.text,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: widget.expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowDown01,
                      color: c.textTertiary,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniBadge(
                    icon: _categoryIcon(widget.item.category),
                    label: _categoryLabel(widget.item.category),
                  ),
                  _MiniBadge(
                    icon: HugeIcons.strokeRoundedRoute01,
                    label: 'support.faq_card_badge'.tr(),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: MarkdownBody(
                    data: widget.item.answer,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                      p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: c.textSecondary,
                            height: 1.55,
                          ),
                      listBullet: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
                crossFadeState: widget.expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
                sizeCurve: Curves.easeOutCubic,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon, required this.label});

  final HugeIconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.sac.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.sac.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, color: context.sac.textSecondary, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: context.sac.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqEmpty extends StatelessWidget {
  const _FaqEmpty({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.sac.border),
      ),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            color: context.sac.textTertiary,
            size: 46,
          ),
          const SizedBox(height: 12),
          Text(
            query.isEmpty
                ? 'support.faq_empty'.tr()
                : 'support.faq_no_results'.tr(args: [query]),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.sac.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _FaqError extends StatelessWidget {
  const _FaqError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

String _categoryLabel(String category) {
  return 'support.faq_category.$category'.tr();
}

String _faqCopy(BuildContext context, String key) {
  if (context.locale.languageCode != 'es') return key.tr();

  switch (key) {
    case 'support.faq_hero_title':
      return 'Mapa de respuestas';
  }

  return key.tr();
}

String _faqHeroBody(BuildContext context, int totalItems) {
  if (context.locale.languageCode != 'es') {
    return 'support.faq_hero_body'.tr(args: ['$totalItems']);
  }

  return 'Consulta $totalItems respuestas organizadas como una ruta de campamento.';
}

HugeIconData _categoryIcon(String category) {
  switch (category) {
    case 'account':
      return HugeIcons.strokeRoundedUserCircle;
    case 'notifications':
      return HugeIcons.strokeRoundedNotification01;
    case 'offline':
      return HugeIcons.strokeRoundedCloud;
    case 'privacy':
      return HugeIcons.strokeRoundedShield01;
    case 'profile':
      return HugeIcons.strokeRoundedUserEdit01;
    case 'support':
      return HugeIcons.strokeRoundedCustomerSupport;
    case 'onboarding':
      return HugeIcons.strokeRoundedCompass01;
    default:
      return HugeIcons.strokeRoundedHelpCircle;
  }
}
