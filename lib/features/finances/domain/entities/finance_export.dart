import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Formato del archivo que exporta el servidor para un mes de finanzas.
enum FinanceExportFormat {
  xlsx('xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  pdf('pdf', 'application/pdf');

  const FinanceExportFormat(this.apiValue, this.mimeType);

  /// Valor del query param `format` y extensión del archivo.
  final String apiValue;
  final String mimeType;
}

/// Archivo descargado: contenido y el nombre con el que se comparte.
class FinanceExportFile extends Equatable {
  final Uint8List bytes;
  final String fileName;

  const FinanceExportFile({required this.bytes, required this.fileName});

  @override
  List<Object?> get props => [bytes, fileName];
}
