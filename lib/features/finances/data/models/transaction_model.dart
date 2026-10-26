import '../../domain/entities/finance_category.dart';
import '../../domain/entities/transaction.dart';
import 'finance_category_model.dart';

class FinanceEvidenceModel extends FinanceEvidence {
  const FinanceEvidenceModel({
    required super.id,
    required super.financeId,
    required super.url,
    required super.fileName,
    required super.fileType,
    super.fileSize,
    required super.uploadedById,
    required super.uploadedAt,
    required super.active,
  });

  factory FinanceEvidenceModel.fromJson(Map<String, dynamic> json) {
    return FinanceEvidenceModel(
      id: FinanceTransactionModel._parseInt(
        json['evidence_id'] ?? json['finance_evidence_file_id'] ?? json['id'],
      ),
      financeId: FinanceTransactionModel._parseInt(
          json['finance_id'] ?? json['financeId']),
      url: (json['url'] ?? json['file_url'] ?? '').toString(),
      fileName: (json['file_name'] ?? json['fileName'] ?? '').toString(),
      fileType:
          (json['file_type'] ?? json['fileType'] ?? 'image/jpeg').toString(),
      fileSize: json['file_size'] == null && json['fileSize'] == null
          ? null
          : FinanceTransactionModel._parseInt(
              json['file_size'] ?? json['fileSize']),
      uploadedById:
          (json['uploaded_by_id'] ?? json['uploadedById'] ?? '').toString(),
      uploadedAt: FinanceTransactionModel._parseDateTime(
          json['uploaded_at'] ?? json['uploadedAt']),
      active: json['active'] as bool? ?? true,
    );
  }

  FinanceEvidence toEntity() => FinanceEvidence(
        id: id,
        financeId: financeId,
        url: url,
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
        uploadedById: uploadedById,
        uploadedAt: uploadedAt,
        active: active,
      );
}

class FinanceTransactionModel extends FinanceTransaction {
  const FinanceTransactionModel({
    required super.id,
    required super.type,
    required super.amount,
    required super.description,
    super.notes,
    required super.date,
    required super.year,
    required super.month,
    required super.category,
    required super.registeredByName,
    super.registeredByPhoto,
    required super.registeredAt,
    super.modifiedByName,
    super.modifiedAt,
    super.evidences,
  });

  factory FinanceTransactionModel.fromJson(Map<String, dynamic> json) {
    // La BD tiene amount como Int (puede representar centavos o la cantidad directa).
    // El backend puede devolver la categoría embebida o solo el ID.
    // El objeto anidado de GET /clubs/:id/finances trae nombre y tipo pero no
    // el id; el id va en la raíz. Sin él, editar no puede preseleccionar la
    // categoría.
    final embedded = json['finances_categories'] as Map<String, dynamic>? ??
        json['category'] as Map<String, dynamic>?;
    final categoryJson = embedded == null
        ? {
            'finance_category_id': json['finance_category_id'] ?? 0,
            'name': 'General',
            'type': 0
          }
        : {
            if (json['finance_category_id'] != null)
              'finance_category_id': json['finance_category_id'],
            ...embedded,
          };

    final category = FinanceCategoryModel.fromJson(categoryJson).toEntity();

    // Determinar tipo por el contrato vigente del backend:
    // finances_categories.type: 0=ingreso, 1=egreso.
    // Si no se puede determinar, usar el campo 'type' si existe.
    final rawType =
        json['type']?.toString() ?? json['transaction_type']?.toString() ?? '';
    final type = _parseType(rawType, category);

    // Datos del creador
    final createdByUser = json['users'] as Map<String, dynamic>? ?? {};
    final registeredByName = _extractName(
        createdByUser, json['created_by']?.toString() ?? 'Sistema');
    final registeredByPhoto = createdByUser['user_image']?.toString();
    final evidences = (json['evidences'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => FinanceEvidenceModel.fromJson(e).toEntity())
        .toList();

    return FinanceTransactionModel(
      id: _parseInt(json['finance_id'] ?? json['id'] ?? 0),
      type: type,
      amount: _parseDouble(json['amount'] ?? 0),
      description: (json['description'] ?? 'Sin descripción').toString(),
      notes: json['notes']?.toString(),
      date: _parseCalendarDate(json['finance_date'] ?? json['date']),
      year: _parseInt(json['year'] ?? DateTime.now().year),
      month: _parseInt(json['month'] ?? DateTime.now().month),
      category: category,
      registeredByName: registeredByName,
      registeredByPhoto: registeredByPhoto,
      registeredAt: _parseDateTime(json['created_at']),
      modifiedByName: json['modified_by_name']?.toString(),
      modifiedAt: json['modified_at'] != null
          ? _parseDateTime(json['modified_at'])
          : null,
      evidences: evidences,
    );
  }

  static TransactionType _parseType(String raw, FinanceCategory category) {
    if (raw == 'income' || raw == '0' || raw == 'ingreso') {
      return TransactionType.income;
    }
    if (raw == 'expense' || raw == '1' || raw == '2' || raw == 'egreso') {
      return TransactionType.expense;
    }
    // Inferir por el tipo de categoría
    if (category.typeCode == 0) return TransactionType.income;
    if (category.typeCode != 0) return TransactionType.expense;
    return TransactionType.income; // default
  }

  static String _extractName(Map<String, dynamic> user, String fallback) {
    if (user.isEmpty) return fallback;
    final name = user['name']?.toString() ?? '';
    final lastName = user['paternal_last_name']?.toString() ?? '';
    final full = '$name $lastName'.trim();
    return full.isNotEmpty ? full : fallback;
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  static DateTime _parseDateTime(dynamic v) => _parseDate(v);

  /// `finance_date` es un día de calendario que el backend manda como
  /// medianoche UTC. Se arma en hora local con solo `YYYY-MM-DD` para que
  /// `toLocal()` no lo mueva al día anterior en México.
  static DateTime _parseCalendarDate(dynamic v) {
    if (v is DateTime) return DateTime(v.year, v.month, v.day);
    final text = v?.toString() ?? '';
    final parsed =
        text.length >= 10 ? DateTime.tryParse(text.substring(0, 10)) : null;
    if (parsed == null) return _parseDate(v);
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  FinanceTransaction toEntity() => FinanceTransaction(
        id: id,
        type: type,
        amount: amount,
        description: description,
        notes: notes,
        date: date,
        year: year,
        month: month,
        category: category,
        registeredByName: registeredByName,
        registeredByPhoto: registeredByPhoto,
        registeredAt: registeredAt,
        modifiedByName: modifiedByName,
        modifiedAt: modifiedAt,
        evidences: evidences,
      );
}
