import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';

import '../providers/support_providers.dart';
import '../widgets/support_chrome.dart';
import 'contact_view.dart';
import 'faq_view.dart';
import 'report_problem_view.dart';

class SupportView extends ConsumerStatefulWidget {
  const SupportView({super.key});

  static const String routeName = '/settings/support';

  @override
  ConsumerState<SupportView> createState() => _SupportViewState();
}

class _SupportViewState extends ConsumerState<SupportView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openFaq() {
    ref.read(faqSearchQueryProvider.notifier).state = _searchCtrl.text.trim();
    context.push(FaqView.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final scheme = Theme.of(context).colorScheme;
    final padding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: supportAppBar(context, title: 'support.title'.tr()),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          padding,
          8,
          padding,
          28 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          StaggeredListItem(
            index: 0,
            staggerDelay: SacMotion.stagger,
            duration: SacMotion.standard,
            slideOffset: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'support.hub_title'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.6,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'support.hub_intro'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.textSecondary,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          StaggeredListItem(
            index: 1,
            staggerDelay: SacMotion.stagger,
            duration: SacMotion.standard,
            slideOffset: 8,
            child: Semantics(
              textField: true,
              label: 'support.hub_search_hint'.tr(),
              child: SacTextField(
                controller: _searchCtrl,
                hint: 'support.hub_search_hint'.tr(),
                prefixIcon: HugeIcons.strokeRoundedSearch01,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _openFaq(),
                suffix: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'common.clear'.tr(),
                        onPressed: () {
                          setState(_searchCtrl.clear);
                        },
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedCancelCircle,
                          size: 20,
                          color: c.textTertiary,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          StaggeredListItem(
            index: 2,
            staggerDelay: SacMotion.stagger,
            duration: SacMotion.standard,
            slideOffset: 8,
            child: SupportDestinationList(
              items: [
                SupportDestination(
                  icon: HugeIcons.strokeRoundedHelpCircle,
                  iconColor: scheme.primary,
                  iconBackground: scheme.primary.withValues(alpha: 0.12),
                  title: 'support.faq_tile'.tr(),
                  subtitle: 'support.faq_tile_subtitle'.tr(),
                  onTap: _openFaq,
                ),
                SupportDestination(
                  icon: HugeIcons.strokeRoundedMail01,
                  iconColor: scheme.secondary,
                  iconBackground: scheme.secondary.withValues(alpha: 0.12),
                  title: 'support.contact_tile'.tr(),
                  subtitle: 'support.contact_tile_subtitle'.tr(),
                  onTap: () => context.push(ContactView.routeName),
                ),
                SupportDestination(
                  icon: HugeIcons.strokeRoundedBug01,
                  iconColor: scheme.tertiary,
                  iconBackground: scheme.tertiary.withValues(alpha: 0.12),
                  title: 'support.report_tile'.tr(),
                  subtitle: 'support.report_tile_subtitle'.tr(),
                  onTap: () => context.push(ReportProblemView.routeName),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
