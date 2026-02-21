import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../main.dart';
import '../../constants/app_constants.dart';

/// Widget para cambiar entre tema claro y oscuro
class ThemeToggle extends ConsumerWidget {
  /// Determina si se debe mostrar el texto junto al icono
  final bool showText;
  
  /// Color del icono y texto (opcional)
  final Color? color;
  
  const ThemeToggle({
    super.key, 
    this.showText = false,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observamos el tema para reaccionar a cambios
    ref.watch(themeProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(AppConstants.paddingS),
      onTap: () => ref.read(themeProvider).toggleTheme(),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingS),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: isDarkMode ? HugeIcons.strokeRoundedSun01 : HugeIcons.strokeRoundedMoon,
              color: color ?? Colors.black,
              size: 24,
            ),
            if (showText) ...[
              const SizedBox(width: AppConstants.paddingS),
              Text(
                isDarkMode ? 'Tema claro' : 'Tema oscuro',
                style: TextStyle(color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
