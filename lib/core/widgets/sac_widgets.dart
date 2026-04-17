/// SACDIA Design System - Widget Exports
///
/// Barrel file para importar todos los componentes del design system
/// con un solo import:
///
/// ```dart
/// import 'package:sacdia_app/core/widgets/sac_widgets.dart';
/// ```
library;

export 'sac_badge.dart';
export 'sac_button.dart';
export 'sac_card.dart';
export 'sac_dialog.dart';
export 'sac_dropdown_field.dart';
export 'sac_loading.dart';
export 'sac_pdf_viewer.dart';
export 'sac_progress_bar.dart';
export 'sac_progress_ring.dart';
export 'sac_text_field.dart';
export 'section_switcher_sheet.dart';

// NOTE: sac_image_viewer.dart is intentionally not exported here because
// SacImageViewer is launched via Navigator.push and carries its own routing
// context; it is not a composable widget meant for direct embedding.
