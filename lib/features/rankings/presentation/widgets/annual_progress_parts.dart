import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_network_image.dart';
import '../../domain/entities/annual_ranking_progress.dart';
import '../theme/ranking_tokens.dart';
import '../utils/ranking_tier_medal_assets.dart';

/// Gray and faded: the medal that is not earned yet.
const ColorFilter kUnearnedMedalFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 0.4, 0, //
]);

/// Neutral track visible in both modes (7% ink over the surface).
Color annualTrackColor(SacColors colors) =>
    Color.alphaBlend(colors.text.withValues(alpha: 0.07), colors.surface);

/// Tier color with a dark variant that reads on dark surfaces.
Color annualTierColor(BuildContext context, RankingTier? tier) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final key = (tier?.slug ?? tier?.name ?? '').toLowerCase();

  if (key.contains('silver') || key.contains('plata')) {
    return isDark
        ? RankingTokens.tierSilverDark
        : RankingTokens.tierSilverLight;
  }
  if (key.contains('gold') || key.contains('oro')) {
    return isDark ? RankingTokens.tierGoldDark : RankingTokens.tierGoldLight;
  }
  if (key.contains('diamond') || key.contains('diamante')) {
    return isDark
        ? RankingTokens.tierDiamondDark
        : RankingTokens.tierDiamondLight;
  }
  return isDark ? RankingTokens.tierBronzeDark : RankingTokens.tierBronzeLight;
}

/// Axis colors: known keys first, then a fixed palette by position, so two
/// axes never share a color (the legend and the blocks must tell them apart).
Color annualAxisColor(String key, int index) {
  final normalized = key.toLowerCase();
  if (normalized == 'operational' || normalized.contains('oper')) {
    return AppColors.secondary;
  }
  if (normalized == 'administrative' || normalized.contains('admin')) {
    return AppColors.info;
  }
  const palette = [AppColors.info, AppColors.secondary, AppColors.accentDark];
  return palette[index % palette.length];
}

/// Uppercase eyebrow with an optional trailing value (count, total).
class AnnualEyebrow extends StatelessWidget {
  const AnnualEyebrow({super.key, required this.label, this.trailing});

  /// Already translated; shown uppercase.
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final style = TextStyle(
      fontSize: SacFontSize.labelSmall,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: c.textTertiary,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          Expanded(child: Text(label.toUpperCase(), style: style)),
          if (trailing != null)
            Text(
              trailing!,
              style: style.copyWith(
                letterSpacing: 0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}

/// Medal of a tier. Order: remote `imageUrl`, local SVG by slug, tinted icon.
/// [unearned] draws it gray and faded.
class AnnualTierMedal extends StatelessWidget {
  const AnnualTierMedal({
    super.key,
    required this.tier,
    required this.size,
    this.unearned = false,
  });

  final RankingTier? tier;
  final double size;
  final bool unearned;

  @override
  Widget build(BuildContext context) {
    final medal = _build(context);
    if (!unearned) return medal;
    // ColorFiltered (not Opacity): Opacity over an SVG breaks on Impeller.
    return ColorFiltered(colorFilter: kUnearnedMedalFilter, child: medal);
  }

  Widget _build(BuildContext context) {
    final remoteUrl = tier?.imageUrl?.trim();
    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      return SacNetworkImage(
        imageUrl: remoteUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        memCacheWidth: (size * 3).round(),
        memCacheHeight: (size * 3).round(),
        errorWidget: (_, __, ___) => _iconMedal(context),
      );
    }

    final asset = rankingTierLocalSvgAsset(tier?.slug ?? tier?.name);
    if (asset != null) {
      return SvgPicture.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _iconMedal(context),
      );
    }

    return _iconMedal(context);
  }

  Widget _iconMedal(BuildContext context) {
    final color = annualTierColor(context, tier);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.95),
            color.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedMedal05,
        size: size * 0.48,
        color: Colors.white.withValues(alpha: 0.95),
      ),
    );
  }
}

/// Text where [emphasis] (a number inside an already translated sentence) is
/// bold. Falls back to plain text when the token is not found.
class AnnualEmphasisText extends StatelessWidget {
  const AnnualEmphasisText({
    super.key,
    required this.text,
    required this.emphasis,
    required this.style,
    this.textAlign,
  });

  final String text;
  final String emphasis;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final index = emphasis.isEmpty ? -1 : text.indexOf(emphasis);
    if (index < 0) return Text(text, style: style, textAlign: textAlign);

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: emphasis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: context.sac.text,
            ),
          ),
          TextSpan(text: text.substring(index + emphasis.length)),
        ],
      ),
      textAlign: textAlign,
    );
  }
}
