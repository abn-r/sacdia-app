import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:haze/haze.dart';

import 'package:sacdia_app/core/theme/sac_accent.dart';
import '../theme/sac_colors.dart';
import 'sac_back_button.dart';

/// iOS-inspired SACDIA top navigation primitives.
///
/// These widgets intentionally keep Flutter's navigation semantics while
/// centralizing the app's visual language: clean surfaces,
/// 48dp touch targets, SF Pro/system typography, and SACDIA coral accents.
class SacTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? titleIcon;
  final Widget? leading;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool automaticallyImplyLeading;
  final bool centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final PreferredSizeWidget? bottom;

  /// Desenfoca lo que se desliza detrás de la barra.
  ///
  /// El [Scaffold] debe usar `extendBodyBehindAppBar: true` y el scroll
  /// debe reservar [frostedInset] arriba para que el primer contenido
  /// arranque debajo de la barra.
  final bool frosted;

  const SacTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.titleIcon,
    this.leading,
    this.actions = const [],
    this.onBack,
    this.automaticallyImplyLeading = true,
    this.centerTitle = false,
    this.backgroundColor,
    this.foregroundColor,
    this.bottom,
    this.frosted = false,
  });

  static const double compactHeight = 56;
  static const double subtitleHeight = 64;
  static const double touchTarget = 48;

  /// Alto de la barra, incluido el status bar, para el padding del scroll.
  static double frostedInset(BuildContext context) {
    final height = Scaffold.maybeOf(context)?.appBarMaxHeight;
    if (height != null && height > 0) return height;
    return MediaQuery.paddingOf(context).top + compactHeight;
  }

  /// Suma el alto de la barra al padding superior de un scroll.
  ///
  /// [context] tiene que estar debajo del [Scaffold] de la barra.
  static EdgeInsets paddingBelowBar(BuildContext context, EdgeInsets padding) {
    return padding.copyWith(top: padding.top + frostedInset(context));
  }

  double get _toolbarHeight =>
      subtitle == null ? compactHeight : subtitleHeight;

  /// La barra esmerilada es transparente. Flutter mediría ese negro
  /// transparente como fondo oscuro y pintaría hora y batería en blanco.
  static SystemUiOverlayStyle _statusBarOnSurface(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
      statusBarBrightness: light ? Brightness.light : Brightness.dark,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        _toolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final canPop = Navigator.of(context).canPop();
    final resolvedForeground = foregroundColor ?? c.text;
    final barColor = backgroundColor ?? c.background;
    final showBack = leading == null &&
        automaticallyImplyLeading &&
        (onBack != null || canPop);

    return AppBar(
      toolbarHeight: _toolbarHeight,
      automaticallyImplyLeading: false,
      backgroundColor: frosted ? Colors.transparent : barColor,
      forceMaterialTransparency: frosted,
      systemOverlayStyle: frosted ? _statusBarOnSurface(context) : null,
      foregroundColor: resolvedForeground,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      leadingWidth: showBack || leading != null ? 56 : 0,
      leading: leading ??
          (showBack
              ? SacBackButton(
                  color: resolvedForeground,
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                )
              : null),
      titleSpacing: showBack || leading != null ? 0 : 20,
      title: _SacTopBarTitle(
        title: title,
        subtitle: subtitle,
        titleIcon: titleIcon,
        centerTitle: centerTitle,
        foregroundColor: resolvedForeground,
      ),
      actions: actions,
      bottom: bottom,
    );
  }
}

/// Desenfoque progresivo detrás de una [SacTopBar] con [SacTopBar.frosted].
///
/// El blur es máximo arriba y se disuelve hacia abajo, [fadeExtension] px
/// por debajo de la barra. El título queda nítido porque la barra no pinta fondo.
class SacFrostedVeil extends StatelessWidget {
  const SacFrostedVeil({super.key, required this.child, this.tint});

  final Widget child;

  /// Color del velo. Su alfa es la opacidad máxima, arriba del todo.
  final Color? tint;

  /// Cuánto sigue el blur por debajo de la barra, en px lógicos.
  static const double fadeExtension = 44;

  @override
  Widget build(BuildContext context) {
    final top = SacTopBar.frostedInset(context);
    final dark = Theme.brightnessOf(context) == Brightness.dark;
    final wash =
        tint ?? (dark ? const Color(0xB3000000) : const Color(0xB3FFFFFF));

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: top + fadeExtension,
          child: IgnorePointer(
            child: Haze(
              edge: HazeEdge.top,
              sigma: 12,
              tint: wash,
            ),
          ),
        ),
      ],
    );
  }
}

class SacSliverTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? titleIcon;
  final Widget? leading;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool automaticallyImplyLeading;
  final bool largeTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const SacSliverTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.titleIcon,
    this.leading,
    this.actions = const [],
    this.onBack,
    this.automaticallyImplyLeading = true,
    this.largeTitle = true,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final canPop = Navigator.of(context).canPop();
    final resolvedForeground = foregroundColor ?? c.text;
    final showBack = leading == null &&
        automaticallyImplyLeading &&
        (onBack != null || canPop);
    final bg = backgroundColor ?? c.background;

    if (!largeTitle) {
      return SliverAppBar(
        pinned: true,
        toolbarHeight: SacTopBar.compactHeight,
        automaticallyImplyLeading: false,
        backgroundColor: bg,
        foregroundColor: resolvedForeground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: showBack || leading != null ? 56 : 0,
        leading: leading ??
            (showBack
                ? SacBackButton(
                    color: resolvedForeground,
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  )
                : null),
        title: _SacTopBarTitle(
          title: title,
          subtitle: subtitle,
          titleIcon: titleIcon,
          foregroundColor: resolvedForeground,
        ),
        actions: actions,
      );
    }

    return SliverAppBar(
      pinned: true,
      expandedHeight: subtitle == null ? 108 : 124,
      toolbarHeight: SacTopBar.compactHeight,
      automaticallyImplyLeading: false,
      backgroundColor: bg,
      foregroundColor: resolvedForeground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: showBack || leading != null ? 56 : 0,
      leading: leading ??
          (showBack
              ? SacBackButton(
                  color: resolvedForeground,
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                )
              : null),
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsetsDirectional.only(
          start: showBack || leading != null ? 56 : 20,
          end: actions.isEmpty ? 20 : 56,
          bottom: 16,
        ),
        title: _SacLargeTitle(
          title: title,
          subtitle: subtitle,
          titleIcon: titleIcon,
          foregroundColor: resolvedForeground,
        ),
      ),
    );
  }
}

class SacFloatingTopBar extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final Color? foregroundColor;
  final Color? backgroundColor;

  const SacFloatingTopBar({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.onBack,
    this.foregroundColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final resolvedForeground = foregroundColor ?? c.text;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: backgroundColor ?? c.surface.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.border.withValues(alpha: 0.8)),
                boxShadow: [
                  BoxShadow(
                    color: c.shadow,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  leading ??
                      SacBackButton(
                        color: resolvedForeground,
                        onPressed:
                            onBack ?? () => Navigator.of(context).maybePop(),
                      ),
                  if (title != null)
                    Expanded(
                      child: _SacTopBarTitle(
                        title: title!,
                        subtitle: subtitle,
                        foregroundColor: resolvedForeground,
                      ),
                    )
                  else
                    const Spacer(),
                  ...actions,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SacTopBarTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? titleIcon;
  final bool centerTitle;
  final Color foregroundColor;

  const _SacTopBarTitle({
    required this.title,
    required this.foregroundColor,
    this.subtitle,
    this.titleIcon,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: centerTitle ? TextAlign.center : TextAlign.start,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: foregroundColor,
            letterSpacing: -0.2,
          ),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        titleText,
        if (subtitle != null) ...[
          const SizedBox(height: 1),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centerTitle ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.sac.textSecondary,
                  height: 1.2,
                ),
          ),
        ],
      ],
    );

    if (titleIcon == null) return content;

    return Row(
      mainAxisSize: centerTitle ? MainAxisSize.min : MainAxisSize.max,
      children: [
        _IconBadge(child: titleIcon!),
        const SizedBox(width: 12),
        Flexible(child: content),
      ],
    );
  }
}

class _SacLargeTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? titleIcon;
  final Color foregroundColor;

  const _SacLargeTitle({
    required this.title,
    required this.foregroundColor,
    this.subtitle,
    this.titleIcon,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: foregroundColor,
                letterSpacing: -0.4,
              ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.sac.textSecondary,
                  height: 1.2,
                ),
          ),
      ],
    );

    if (titleIcon == null) return content;

    return Row(
      children: [
        _IconBadge(child: titleIcon!),
        const SizedBox(width: 12),
        Flexible(child: content),
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  final Widget child;

  const _IconBadge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SacAccent.of(context).light,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconTheme(
        data: IconThemeData(color: SacAccent.of(context).color, size: 22),
        child: child,
      ),
    );
  }
}
