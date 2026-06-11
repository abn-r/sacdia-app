import 'dart:async';

import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

import '../theme/app_colors.dart';

const _sacOnboardingScopeName = 'sacdia_onboarding';

/// App-wide scope for contextual onboarding helpers.
///
/// Keep [showcaseview] behind this project API so feature screens do not
/// depend on third-party package details.
class SacOnboardingScope extends StatefulWidget {
  const SacOnboardingScope({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<SacOnboardingScope> createState() => _SacOnboardingScopeState();
}

class _SacOnboardingScopeState extends State<SacOnboardingScope> {
  final Map<String, GlobalKey> _anchorKeys = {};
  final Map<String, _SacOnboardingConfig> _configs = {};
  late final ShowcaseView _showcaseView;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _showcaseView = ShowcaseView.register(
      scope: _sacOnboardingScopeName,
      skipIfTargetNotPresent: true,
      enableAutoScroll: true,
      disableBarrierInteraction: false,
      semanticEnable: true,
      overlayColor: Colors.black,
      overlayOpacity: 0.72,
      scrollDuration: const Duration(milliseconds: 260),
      disableMovingAnimation: false,
      disableScaleAnimation: false,
    );
  }

  @override
  void dispose() {
    _showcaseView.unregister();
    super.dispose();
  }

  GlobalKey keyFor(String id) {
    return _anchorKeys.putIfAbsent(
      id,
      () => GlobalKey(debugLabel: 'SacOnboardingAnchor:$id'),
    );
  }

  _SacOnboardingConfig? configFor(String id) => _configs[id];

  Future<void> showAnchoredHelper(
    BuildContext context, {
    required String anchorId,
    required _SacOnboardingConfig config,
  }) async {
    final key = keyFor(anchorId);
    final completer = Completer<void>();

    setState(() {
      _configs[anchorId] = config;
      _version++;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        if (!completer.isCompleted) completer.complete();
        return;
      }

      _showcaseView.startShowCase([key]);
      if (!completer.isCompleted) completer.complete();
    });

    return completer.future;
  }

  void hide() {
    if (_showcaseView.isShowcaseRunning) {
      _showcaseView.dismiss();
    }
  }

  static _SacOnboardingScopeState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SacOnboardingInherited>()
        ?.state;
  }

  @override
  Widget build(BuildContext context) {
    return _SacOnboardingInherited(
      state: this,
      version: _version,
      child: widget.child,
    );
  }
}

class _SacOnboardingInherited extends InheritedWidget {
  const _SacOnboardingInherited({
    required this.state,
    required this.version,
    required super.child,
  });

  final _SacOnboardingScopeState state;
  final int version;

  @override
  bool updateShouldNotify(_SacOnboardingInherited oldWidget) {
    return version != oldWidget.version || state != oldWidget.state;
  }
}

/// Registers [child] as a target that can later be highlighted by
/// [SacOnboarding.showAnchoredHelper].
class SacOnboardingAnchor extends StatelessWidget {
  const SacOnboardingAnchor({
    super.key,
    required this.id,
    required this.child,
    this.enabled = true,
  });

  final String id;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scope = _SacOnboardingScopeState.maybeOf(context);
    if (!enabled || scope == null) return child;

    final config =
        scope.configFor(id) ?? _SacOnboardingConfig.fallback(context);

    return Showcase(
      key: scope.keyFor(id),
      scope: _sacOnboardingScopeName,
      title: config.title,
      description: config.description,
      titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ) ??
          const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
      descTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
                height: 1.35,
              ) ??
          TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 14,
            height: 1.35,
          ),
      tooltipBackgroundColor: config.backgroundColor,
      textColor: Colors.white,
      tooltipBorderRadius: BorderRadius.circular(18),
      tooltipPadding: const EdgeInsets.all(16),
      toolTipMargin: 16,
      targetTooltipGap: 12,
      targetPadding: const EdgeInsets.all(8),
      targetShapeBorder: switch (config.anchorShape) {
        SacOnboardingAnchorShape.circle => const CircleBorder(),
        SacOnboardingAnchorShape.rectangle => RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
      },
      tooltipPosition: _toShowcasePosition(config.alignment),
      showArrow: true,
      enableAutoScroll: true,
      disableBarrierInteraction: !config.dismissOnBackgroundTap,
      onBarrierClick: config.dismissOnBackgroundTap
          ? () => config.onBackgroundTap?.call()
          : null,
      onTargetClick: config.onAnchorTap == null
          ? null
          : () {
              scope.hide();
              config.onAnchorTap?.call();
            },
      disposeOnTap: config.onAnchorTap == null ? null : true,
      tooltipActionConfig: const TooltipActionConfig(
        position: TooltipActionPosition.inside,
        alignment: MainAxisAlignment.end,
        actionGap: 10,
        gapBetweenContentAndAction: 14,
      ),
      tooltipActions: _buildActions(context, scope, config),
      child: child,
    );
  }

  static List<TooltipActionButton> _buildActions(
    BuildContext context,
    _SacOnboardingScopeState scope,
    _SacOnboardingConfig config,
  ) {
    final actions = <TooltipActionButton>[];
    final labelStyle = Theme.of(context).textTheme.labelLarge;

    if (config.secondaryActionLabel != null) {
      actions.add(
        TooltipActionButton(
          type: TooltipDefaultActionType.skip,
          name: config.secondaryActionLabel,
          backgroundColor: Colors.white.withValues(alpha: 0.14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
          textStyle: labelStyle?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          onTap: () {
            scope.hide();
            config.onSecondaryAction?.call();
          },
        ),
      );
    }

    actions.add(
      TooltipActionButton(
        type: TooltipDefaultActionType.next,
        name: config.primaryActionLabel,
        backgroundColor: Colors.white,
        textStyle: labelStyle?.copyWith(
          color: config.backgroundColor,
          fontWeight: FontWeight.w800,
        ),
        onTap: () {
          ShowcaseView.getNamed(_sacOnboardingScopeName).next(force: true);
          config.onPrimaryAction?.call();
        },
      ),
    );

    return actions;
  }

  static TooltipPosition? _toShowcasePosition(
    SacOnboardingAlignment? alignment,
  ) {
    return switch (alignment) {
      null => null,
      SacOnboardingAlignment.top => TooltipPosition.top,
      SacOnboardingAlignment.bottom => TooltipPosition.bottom,
      SacOnboardingAlignment.left => TooltipPosition.left,
      SacOnboardingAlignment.right => TooltipPosition.right,
    };
  }
}

enum SacOnboardingAlignment { top, bottom, left, right }

enum SacOnboardingAnchorShape { circle, rectangle }

class SacOnboarding {
  const SacOnboarding._();

  static Future<void> showAnchoredHelper(
    BuildContext context, {
    required String anchorId,
    required String title,
    required String description,
    String? primaryActionLabel,
    String? secondaryActionLabel,
    VoidCallback? onPrimaryAction,
    VoidCallback? onSecondaryAction,
    VoidCallback? onAnchorTap,
    VoidCallback? onBackgroundTap,
    VoidCallback? onError,
    Color backgroundColor = AppColors.primary,
    SacOnboardingAlignment? alignment,
    SacOnboardingAnchorShape anchorShape = SacOnboardingAnchorShape.circle,
    bool isInModal = false,
    bool dismissOnBackgroundTap = false,
  }) async {
    final scope = _SacOnboardingScopeState.maybeOf(context);
    if (scope == null) {
      onError?.call();
      return;
    }

    return scope.showAnchoredHelper(
      context,
      anchorId: anchorId,
      config: _SacOnboardingConfig(
        title: title,
        description: description,
        primaryActionLabel: primaryActionLabel ??
            MaterialLocalizations.of(context).okButtonLabel,
        secondaryActionLabel: secondaryActionLabel,
        onPrimaryAction: onPrimaryAction,
        onSecondaryAction: onSecondaryAction,
        onAnchorTap: onAnchorTap,
        onBackgroundTap: onBackgroundTap,
        onError: onError,
        backgroundColor: backgroundColor,
        alignment: alignment,
        anchorShape: anchorShape,
        dismissOnBackgroundTap: dismissOnBackgroundTap,
      ),
    );
  }

  static void hide(BuildContext context) {
    _SacOnboardingScopeState.maybeOf(context)?.hide();
  }
}

class _SacOnboardingConfig {
  const _SacOnboardingConfig({
    required this.title,
    required this.description,
    required this.primaryActionLabel,
    this.secondaryActionLabel,
    this.onPrimaryAction,
    this.onSecondaryAction,
    this.onAnchorTap,
    this.onBackgroundTap,
    this.onError,
    required this.backgroundColor,
    this.alignment,
    required this.anchorShape,
    required this.dismissOnBackgroundTap,
  });

  factory _SacOnboardingConfig.fallback(BuildContext context) {
    return _SacOnboardingConfig(
      title: '',
      description: '',
      primaryActionLabel: MaterialLocalizations.of(context).okButtonLabel,
      backgroundColor: AppColors.primary,
      anchorShape: SacOnboardingAnchorShape.circle,
      dismissOnBackgroundTap: false,
    );
  }

  final String title;
  final String description;
  final String primaryActionLabel;
  final String? secondaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final VoidCallback? onAnchorTap;
  final VoidCallback? onBackgroundTap;
  final VoidCallback? onError;
  final Color backgroundColor;
  final SacOnboardingAlignment? alignment;
  final SacOnboardingAnchorShape anchorShape;

  final bool dismissOnBackgroundTap;
}
