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
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/presentation/providers/welcome_carousel_provider.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/auth_sky_wash.dart';
import 'package:sacdia_app/features/auth/presentation/theme/auth_tokens.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_chrome.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_logo_group.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/sac_brand_mark.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_scene_classes.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_scene_converge.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_scene_deck.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_scene_honors.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_scene_impact.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_scene_journey.dart';

/// First-run pre-login carousel: six animated scenes that end on the logo
/// flying into the login screen.
class WelcomeCarouselView extends ConsumerStatefulWidget {
  const WelcomeCarouselView({super.key});

  @override
  ConsumerState<WelcomeCarouselView> createState() =>
      _WelcomeCarouselViewState();
}

class _WelcomeCarouselViewState extends ConsumerState<WelcomeCarouselView> {
  static const _pageCount = 6;
  static const double _sidePadding = 24;
  static const double _topBarHeight = 44;
  static const double _ctaHeight = 56;
  static const double _secondaryHeight = 44;
  static const double _bottomPadding = 24;

  final _pageController = PageController();
  int _index = 0;
  bool _finishing = false;

  /// Scene 1 waits for the logo to be decoded so its entrance never starts
  /// on an empty glow (first frame after a cold start).
  bool _logoReady = false;
  bool _logoPrecacheStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_logoPrecacheStarted) return;
    _logoPrecacheStarted = true;
    // Same decode size SacBrandMark uses for the 173pt welcome logo.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheSize =
        (WelcomeLogoGroup.logoSize * dpr).round().clamp(64, 1024).toInt();
    precacheImage(
      ResizeImage(
        const AssetImage(SacBrandMark.assetPath),
        width: cacheSize,
        height: cacheSize,
      ),
      context,
    ).whenComplete(() {
      if (mounted) setState(() => _logoReady = true);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pageCount - 1;

  Future<void> _goTo(int page) async {
    if (page < 0 || page >= _pageCount || page == _index) return;
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
    if (route == RouteNames.register) {
      // Register is a child of login (it pops back to it on "back", on
      // "Inicia sesión" and after signing up), so open it on top of login.
      context.go(RouteNames.login);
      context.push(RouteNames.register);
      return;
    }
    context.go(route);
  }

  Widget _scene(int i, bool active) => switch (i) {
        0 => WelcomeSceneImpact(active: active && _logoReady),
        1 => WelcomeSceneClasses(active: active),
        2 => WelcomeSceneHonors(active: active),
        3 => WelcomeSceneDeck(active: active),
        4 => WelcomeSceneJourney(active: active),
        _ => WelcomeSceneConverge(active: active),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final link = welcomeLinkColor(context);
    final strength =
        (_index == 0 || _isLast) ? AuthSkyStrength.hero : AuthSkyStrength.soft;

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: reduce ? Duration.zero : SacMotion.routeEnter,
              child: Stack(
                key: ValueKey(strength),
                fit: StackFit.expand,
                children: [AuthSkyWash(strength: strength)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  showBack: _index > 0,
                  link: link,
                  busy: _finishing,
                  onBack: () => _goTo(_index - 1),
                  onSkip: () => _finish(RouteNames.login),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pageCount,
                    physics: _finishing
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, i) => _WelcomePage(
                      key: Key('welcome-page-$i'),
                      stage: RepaintBoundary(child: _scene(i, i == _index)),
                      title: 'welcome_carousel.s${i + 1}_title'.tr(),
                      emphasis: 'welcome_carousel.s${i + 1}_emph'.tr(),
                      body: 'welcome_carousel.s${i + 1}_body'.tr(),
                      animateCopy: i == 0,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
                  child: Column(
                    children: [
                      WelcomeProgress(
                        count: _pageCount,
                        index: _index,
                        onSelect: _finishing ? null : _goTo,
                      ),
                      const SizedBox(height: 6),
                      SacButton(
                        key: Key(
                          _isLast ? 'welcome-create-account' : 'welcome-next',
                        ),
                        text: (_isLast
                                ? 'welcome_carousel.create_account'
                                : 'common.next')
                            .tr(),
                        variant: SacButtonVariant.primary,
                        size: SacButtonSize.large,
                        fullWidth: true,
                        minHeight: _ctaHeight,
                        iconSize: 20,
                        backgroundColor: AppColors.loginBrandBlue,
                        borderRadius: AppTheme.radiusFull,
                        trailingIcon: _isLast
                            ? null
                            : HugeIcons.strokeRoundedArrowRight01,
                        isEnabled: !_finishing,
                        onPressed: _isLast
                            ? () => _finish(RouteNames.register)
                            : () => _goTo(_index + 1),
                      ),
                      _MaybeAnimatedSize(
                        animate: !reduce,
                        child: SizedBox(
                          width: double.infinity,
                          child: _isLast
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: TextButton(
                                    key: const Key('welcome-sign-in'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: link,
                                      minimumSize: const Size(
                                        double.infinity,
                                        _secondaryHeight,
                                      ),
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    onPressed: _finishing
                                        ? null
                                        : () => _finish(RouteNames.login),
                                    child: Text(
                                      'welcome_carousel.have_account'.tr(),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: _bottomPadding),
                    ],
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.showBack,
    required this.link,
    required this.busy,
    required this.onBack,
    required this.onSkip,
  });

  final bool showBack;
  final Color link;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _WelcomeCarouselViewState._topBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: _WelcomeCarouselViewState._topBarHeight,
              child: Visibility(
                visible: showBack,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: SacBackButton(
                  key: const Key('welcome-back'),
                  onPressed: busy ? null : onBack,
                  tooltip: 'common.back'.tr(),
                ),
              ),
            ),
            const Spacer(),
            TextButton(
              key: const Key('welcome-skip'),
              style: TextButton.styleFrom(
                foregroundColor: link,
                minimumSize: const Size(
                  _WelcomeCarouselViewState._topBarHeight,
                  _WelcomeCarouselViewState._topBarHeight,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              onPressed: busy ? null : onSkip,
              child: Text('welcome_carousel.skip'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// One page: the animated stage takes whatever height the copy leaves.
class _WelcomePage extends StatelessWidget {
  const _WelcomePage({
    super.key,
    required this.stage,
    required this.title,
    required this.emphasis,
    required this.body,
    required this.animateCopy,
  });

  final Widget stage;
  final String title;
  final String emphasis;
  final String body;
  final bool animateCopy;

  static const double _copyPadding = 24;
  static const double _copyBottom = 8;
  static const double _copyMaxShare = 0.6;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(child: stage),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * _copyMaxShare,
              ),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  _copyPadding,
                  4,
                  _copyPadding,
                  _copyBottom,
                ),
                child: WelcomeCopy(
                  title: title,
                  emphasis: emphasis,
                  body: body,
                  animateIn: animateCopy,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// AnimatedSize asserts with a zero duration, so reduced motion skips it.
class _MaybeAnimatedSize extends StatelessWidget {
  const _MaybeAnimatedSize({required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate) return child;
    return AnimatedSize(
      duration: SacMotion.standard,
      curve: SacMotion.easeOut,
      child: child,
    );
  }
}
