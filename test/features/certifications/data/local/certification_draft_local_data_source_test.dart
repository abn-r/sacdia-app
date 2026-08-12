import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sacdia_app/features/certifications/data/local/certification_draft_local_data_source.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_requirement_component.dart';

void main() {
  late Directory tempDir;
  late Box<String> box;
  late CertificationDraftLocalDataSource dataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cert_drafts_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox<String>(CertificationDraftLocalDataSource.boxName);
    dataSource = CertificationDraftLocalDataSource(box);
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('getDraft returns null when nothing was saved yet', () {
    expect(dataSource.getDraft(1, 10), isNull);
  });

  test('saveDraft persists values that getDraft can restore', () async {
    final values = {
      1: const CertificationComponentDraftInput(
        componentId: 1,
        textValue: 'Mi respuesta',
      ),
      2: const CertificationComponentDraftInput(
        componentId: 2,
        attestationConfirmed: true,
      ),
      3: const CertificationComponentDraftInput(
        componentId: 3,
        linkedUserHonorId: 55,
        linkedActivityId: 77,
      ),
    };

    await dataSource.saveDraft(1, 10, values);
    final restored = dataSource.getDraft(1, 10);

    expect(restored, isNotNull);
    expect(restored!.length, 3);
    expect(restored[1]!.textValue, 'Mi respuesta');
    expect(restored[2]!.attestationConfirmed, isTrue);
    expect(restored[3]!.linkedUserHonorId, 55);
    expect(restored[3]!.linkedActivityId, 77);
  });

  test('drafts are keyed by enrollmentId + sectionId independently', () async {
    await dataSource.saveDraft(1, 10, {
      1: const CertificationComponentDraftInput(
        componentId: 1,
        textValue: 'Inscripción 1 / sección 10',
      ),
    });
    await dataSource.saveDraft(1, 20, {
      1: const CertificationComponentDraftInput(
        componentId: 1,
        textValue: 'Inscripción 1 / sección 20',
      ),
    });
    await dataSource.saveDraft(2, 10, {
      1: const CertificationComponentDraftInput(
        componentId: 1,
        textValue: 'Inscripción 2 / sección 10',
      ),
    });

    expect(dataSource.getDraft(1, 10)![1]!.textValue,
        'Inscripción 1 / sección 10');
    expect(dataSource.getDraft(1, 20)![1]!.textValue,
        'Inscripción 1 / sección 20');
    expect(dataSource.getDraft(2, 10)![1]!.textValue,
        'Inscripción 2 / sección 10');
  });

  test('clearDraft removes the persisted draft', () async {
    await dataSource.saveDraft(1, 10, {
      1: const CertificationComponentDraftInput(
        componentId: 1,
        textValue: 'Por borrar',
      ),
    });
    expect(dataSource.getDraft(1, 10), isNotNull);

    await dataSource.clearDraft(1, 10);

    expect(dataSource.getDraft(1, 10), isNull);
  });

  test('getDraft recovers gracefully from corrupted content', () async {
    await box.put(
      CertificationDraftLocalDataSource.keyFor(1, 10),
      'not-valid-json{{{',
    );

    expect(dataSource.getDraft(1, 10), isNull);
  });

  test('saveDraft overwrites the previous draft for the same key', () async {
    await dataSource.saveDraft(1, 10, {
      1: const CertificationComponentDraftInput(
        componentId: 1,
        textValue: 'Primero',
      ),
    });
    await dataSource.saveDraft(1, 10, {
      2: const CertificationComponentDraftInput(
        componentId: 2,
        textValue: 'Segundo',
      ),
    });

    final restored = dataSource.getDraft(1, 10)!;
    expect(restored.containsKey(1), isFalse);
    expect(restored[2]!.textValue, 'Segundo');
  });
}
