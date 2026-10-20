import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/domain/entities/supervised_login.dart';

/// JSON de `DependentSummary` tal como lo devuelve el backend.
Map<String, Object?> dependentJson({
  String id = 'ana-1',
  String name = 'Ana',
  int age = 9,
  String consent = 'pending',
  bool primary = true,
  bool evidence = false,
  bool frozen = false,
  Map<String, Object?>? club,
  String accessMode = 'guardian_managed',
  Map<String, Object?>? supervisedLogin,
  bool ageMilestoneReached = false,
  int linkedDevices = 0,
}) =>
    {
      'user_id': id,
      'name': name,
      'paternal_last_name': 'Pérez',
      'maternal_last_name': 'López',
      'birthday': '2017-04-02',
      'age': age,
      'user_image': null,
      'access_mode': accessMode,
      'supervised_login': supervisedLogin,
      'linked_devices_count': linkedDevices,
      'age_milestone_reached': ageMilestoneReached,
      'post_register_complete': false,
      'frozen': frozen,
      'guardianship': {
        'guardianship_id': 'gs-$id',
        'is_primary': primary,
        'relationship_type': {
          'relationship_type_id': 'rel-1',
          'name': 'Madre',
        },
        'consent_status': consent,
        'verified_at':
            consent == 'verified' ? '2026-10-01T10:00:00.000Z' : null,
        'evidence_uploaded': evidence,
      },
      'club_membership': club,
    };

Map<String, Object?> guardianJson({
  String id = 'gs-1',
  String? userId = 'guardian-1',
  String name = 'María Pérez',
  bool primary = true,
  bool custodian = false,
  bool me = true,
  String consent = 'pending',
}) =>
    {
      'guardianship_id': id,
      'user_id': userId,
      'display_name': name,
      'relationship_type_name': 'Madre',
      'is_primary': primary,
      'is_custodian': custodian,
      'consent_status': consent,
      'is_me': me,
    };

Map<String, Object?> detailJson({
  String id = 'ana-1',
  String name = 'Ana',
  String consent = 'pending',
  bool evidence = false,
  Map<String, Object?>? club,
  List<Map<String, Object?>>? guardians,
  int age = 9,
  String accessMode = 'guardian_managed',
  Map<String, Object?>? supervisedLogin,
  bool ageMilestoneReached = false,
}) =>
    {
      ...dependentJson(
        id: id,
        name: name,
        age: age,
        consent: consent,
        evidence: evidence,
        club: club,
        accessMode: accessMode,
        supervisedLogin: supervisedLogin,
        ageMilestoneReached: ageMilestoneReached,
      ),
      'guardians': guardians ?? [guardianJson()],
    };

const clubPending = {
  'assignment_id': 'asg-1',
  'status': 'pending',
  'club_section_id': 12,
  'club_name': 'Club Águilas',
  'club_type_name': 'Aventureros',
};

DependentSummary summary({
  String id = 'ana-1',
  String name = 'Ana',
  int age = 9,
  String consent = 'pending',
  bool frozen = false,
  AccessMode accessMode = AccessMode.guardianManaged,
  SupervisedLoginInfo? supervisedLogin,
  bool ageMilestoneReached = false,
}) =>
    DependentSummary(
      userId: id,
      name: name,
      paternalLastName: 'Pérez',
      age: age,
      frozen: frozen,
      accessMode: accessMode,
      supervisedLogin: supervisedLogin,
      ageMilestoneReached: ageMilestoneReached,
      guardianship: DependentGuardianship(
        guardianshipId: 'gs-$id',
        isPrimary: true,
        consentStatus: GuardianConsentStatus.parse(consent),
        evidenceUploaded: false,
      ),
    );
