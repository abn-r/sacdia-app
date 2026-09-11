import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/presentation/providers/welcome_carousel_provider.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome_carousel_visuals.dart';

/// First-run pre-login carousel. Rare surface: the stage is the product.
class WelcomeCarouselView extends ConsumerStatefulWidget {
  const WelcomeCarouselView({super.key});

  @override
  ConsumerState<WelcomeCarouselView> createState() =>
      _WelcomeCarouselViewState();
}

class _WelcomeCarouselViewState extends ConsumerState<WelcomeCarouselView> {
  static const _pageCount = 5;
  static const _ctaMinHeight = 44.8;
  static const _ctaPadding = EdgeInsets.symmetric(horizontal: 32, vertical: 12);

  final _pageController = PageController();
  int _index = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pageCount - 1;

  Future<void> _goTo(int page) async {
    if (page < 0 || page >= _pageCount) return;
    if (SacMotion.reduceMotionOf(context)) {
      _pageController.jumpToPage(page);
    } else {
      await _pageController.animateToPage(
        page,
        duration: SacMotion.routeEnter,
        curve: SacMotion.easeOut,
      );
    }
  }

  Future<void> _finish(String route) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await ref.read(welcomeCarouselSeenProvider.notifier).markSeen();
    if (!mounted) return;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = SacMotion.reduceMotionOf(context);
    final pad = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const _OnboardingWash(),
          Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: _finishing
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                  onPageChanged: (value) => setState(() => _index = value),
                  children: [
                    _WelcomeSlide(
                      key: const Key('welcome-page-0'),
                      copyPadding: pad,
                      visual: WelcomeSlideLogo(
                        controller: _pageController,
                        index: 0,
                        reduceMotion: reduceMotion,
                      ),
                      title: 'welcome_carousel.slide1_title'.tr(),
                      titleEmphasis:
                          'welcome_carousel.slide1_title_emphasis'.tr(),
                      body: 'welcome_carousel.slide1_body'.tr(),
                    ),
                    _WelcomeSlide(
                      key: const Key('welcome-page-1'),
                      copyPadding: pad,
                      visual: WelcomeSlideClassPath(
                        controller: _pageController,
                        index: 1,
                        reduceMotion: reduceMotion,
                      ),
                      title: 'welcome_carousel.slide2_title'.tr(),
                      body: 'welcome_carousel.slide2_body'.tr(),
                    ),
                    _WelcomeSlide(
                      key: const Key('welcome-page-2'),
                      copyPadding: pad,
                      visual: WelcomeSlideHonors(
                        controller: _pageController,
                        index: 2,
                        reduceMotion: reduceMotion,
                      ),
                      title: 'welcome_carousel.slide3_title'.tr(),
                      body: 'welcome_carousel.slide3_body'.tr(),
                    ),
                    _WelcomeSlide(
                      key: const Key('welcome-page-3'),
                      copyPadding: pad,
                      visual: WelcomeSlideAdmin(
                        controller: _pageController,
                        index: 3,
                        reduceMotion: reduceMotion,
                      ),
                      title: 'welcome_carousel.slide4_title'.tr(),
                      body: 'welcome_carousel.slide4_body'.tr(),
                    ),
                    _WelcomeSlide(
                      key: const Key('welcome-page-4'),
                      copyPadding: pad,
                      visual: WelcomeSlideJourney(
                        controller: _pageController,
                        index: 4,
                        reduceMotion: reduceMotion,
                      ),
                      title: 'welcome_carousel.slide5_title'.tr(),
                      body: 'welcome_carousel.slide5_body'.tr(),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 15, pad, 15),
                  child: Column(
                    children: [
                      Semantics(
                        label: 'welcome_carousel.page_semantics'.tr(
                          namedArgs: {
                            'current': '${_index + 1}',
                            'total': '$_pageCount',
                          },
                        ),
                        child: _PageDots(
                          count: _pageCount,
                          index: _index,
                          onTap: _finishing ? null : _goTo,
                        ),
                      ),
                      const SizedBox(height: 45),
                      SacButton(
                        key: Key(_isLast ? 'welcome-continue' : 'welcome-next'),
                        text: (_isLast
                                ? 'welcome_carousel.continue'
                                : 'common.next')
                            .tr(),
                        variant: SacButtonVariant.primary,
                        size: SacButtonSize.large,
                        fullWidth: true,
                        minHeight: _ctaMinHeight,
                        padding: _ctaPadding,
                        iconSize: 20,
                        backgroundColor: AppColors.loginBrandBlue,
                        borderRadius: AppTheme.radiusFull,
                        trailingIcon: HugeIcons.strokeRoundedArrowRight01,
                        isEnabled: !_finishing,
                        onPressed: _isLast
                            ? () => _finish(RouteNames.login)
                            : () => _goTo(_index + 1),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    if (_index > 0)
                      IgnorePointer(
                        ignoring: _finishing,
                        child: _FloatingChip(
                          child: SacBackButton(
                            key: const Key('welcome-back'),
                            onPressed: () => _goTo(_index - 1),
                            tooltip: 'common.back'.tr(),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                    const Spacer(),
                    _FloatingChip(
                      child: TextButton(
                        key: const Key('welcome-skip'),
                        onPressed:
                            _finishing ? null : () => _finish(RouteNames.login),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.loginBrandBlueDark,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: Text(
                          'welcome_carousel.skip'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingWash extends StatelessWidget {
  const _OnboardingWash();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.55, -0.42),
              radius: 0.95,
              colors: [
                Color(0x1CFFB020),
                Color(0x00FFB020),
              ],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.5, 0.62),
                radius: 1.05,
                colors: [
                  Color(0x140B84F0),
                  Color(0x000B84F0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingChip extends StatelessWidget {
  const _FloatingChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _WelcomeSlide extends StatelessWidget {
  const _WelcomeSlide({
    super.key,
    required this.visual,
    required this.title,
    required this.body,
    required this.copyPadding,
    this.titleEmphasis,
  });

  final Widget visual;
  final String title;
  final String? titleEmphasis;
  final String body;
  final double copyPadding;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final baseTitle = Theme.of(context).textTheme.headlineSmall;
    final titleStyle = baseTitle?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1.12,
      fontSize: (baseTitle.fontSize ?? 18) * 1.3,
    );

    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: visual),
          Padding(
            padding: EdgeInsets.fromLTRB(copyPadding, 4, copyPadding, 15),
            child: Column(
              children: [
                _EmphasizedTitle(
                  title: title,
                  emphasis: titleEmphasis,
                  style: titleStyle,
                ),
                const SizedBox(height: 20),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: c.textSecondary,
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

class _EmphasizedTitle extends StatelessWidget {
  const _EmphasizedTitle({
    required this.title,
    required this.style,
    this.emphasis,
  });

  final String title;
  final String? emphasis;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final needle = emphasis?.trim() ?? '';
    if (needle.isEmpty) {
      return Text(title, textAlign: TextAlign.center, style: style);
    }
    final i = title.toLowerCase().indexOf(needle.toLowerCase());
    if (i < 0) {
      return Text(title, textAlign: TextAlign.center, style: style);
    }
    final leading = title.substring(0, i).trimRight();
    final matched = title.substring(i, i + needle.length);
    return Semantics(
      label: title,
      child: Column(
        children: [
          Text(leading, textAlign: TextAlign.center, style: style),
          Text(
            matched,
            textAlign: TextAlign.center,
            style: style?.copyWith(color: AppColors.loginBrandBlue),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.index,
    required this.onTap,
  });

  final int count;
  final int index;
  final Future<void> Function(int page)? onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            onTap: onTap == null ? null : () => onTap!(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              child: AnimatedContainer(
                duration: reduce ? Duration.zero : SacMotion.standard,
                curve: SacMotion.easeOut,
                width: i == index ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  color: i == index
                      ? AppColors.loginBrandBlue
                      : context.sac.border,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
