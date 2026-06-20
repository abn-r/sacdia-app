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
    final categoryJson = json['finances_categories'] as Map<String, dynamic>? ??
        json['category'] as Map<String, dynamic>? ??
        {
          'finance_category_id': json['finance_category_id'] ?? 0,
          'name': 'General',
          'type': 0
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
      date: _parseDate(json['finance_date'] ?? json['date']),
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
