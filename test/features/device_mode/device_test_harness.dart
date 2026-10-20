import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_module_detail.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_requirement.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_with_progress.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/device_mode/domain/entities/device_pairing.dart';
import 'package:sacdia_app/features/device_mode/presentation/providers/device_meta_provider.dart';

/// Teléfono vinculado de Ana con un club activo.
UserEntity deviceUser({
  bool legalPending = false,
  bool postRegisterComplete = true,
  int? clubId = 7,
}) =>
    UserEntity(
      id: 'kid-1',
      name: 'Ana',
      postRegisterComplete: postRegisterComplete,
      legalAcceptancePending: legalPending,
      // Como el /auth/me real de un teléfono: el club viaja en `club`, no en
      // `authorization`.
      principal: PrincipalInfo(
        kind: PrincipalKind.linkedDevice,
        device: DeviceInfo(
          linkedDeviceId: 'dev-1',
          label: 'Tablet de Ana',
          clubId: clubId,
          clubName: clubId == null ? null : 'Club Águilas',
          clubType: clubId == null ? null : 'Conquistadores',
        ),
      ),
      authorization: const AuthorizationSnapshot(effectivePermissions: []),
    );

/// `AuthNotifier` fijo que registra el emparejado y el cierre de sesión.
class FakeDeviceAuth extends AuthNotifier {
  FakeDeviceAuth(this.user, {this.pairError});

  UserEntity? user;
  String? pairError;
  final pairCalls = <DevicePairingInput>[];
  int signOutCalls = 0;
  int refreshCalls = 0;

  @override
  Future<UserEntity?> build() async => user;

  @override
  Future<String?> pairDevice(DevicePairingInput input) async {
    pairCalls.add(input);
    return pairError;
  }

  @override
  Future<bool> signOut() async {
    signOutCalls++;
    return true;
  }

  @override
  Future<UserEntity?> refreshCurrentUser({
    bool keepCurrentOnFailure = false,
  }) async {
    refreshCalls++;
    return user;
  }
}

const testMeta = DevicePairingMeta(
  platform: 'android',
  appVersion: '2.4.0',
  defaultLabel: 'Pixel 8',
);

Override metaOverride([DevicePairingMeta meta = testMeta]) =>
    devicePairingMetaProvider.overrideWith((ref) async => meta);

const mathClass = ProgressiveClass(
  id: 3,
  name: 'Amigo',
  clubTypeId: 2,
  enrollmentId: 99,
  overallProgress: 62,
  ecclesiasticalYearLabel: '2026–2027',
);

ClassRequirement requirement(
  int id, {
  RequirementStatus status = RequirementStatus.pendiente,
  String? observation,
  int maxFiles = 3,
}) =>
    ClassRequirement(
      id: id,
      name: 'Requisito $id',
      description: 'Descripción del requisito $id',
      moduleId: 1,
      status: status,
      observationComment: observation,
      maxFiles: maxFiles,
    );

ClassWithProgress classWithProgress({
  List<ClassRequirement>? requirements,
}) =>
    ClassWithProgress(
      id: 3,
      name: 'Amigo',
      clubTypeId: 2,
      enrollmentId: 99,
      overallProgress: 62,
      modules: [
        ClassModuleDetail(
          id: 1,
          name: 'Módulo 1',
          classId: 3,
          requirements: requirements ??
              [
                requirement(10),
                requirement(11, status: RequirementStatus.enviado),
                requirement(12, status: RequirementStatus.validado),
              ],
        ),
      ],
    );

Activity activity(
  int id, {
  DateTime? date,
  String name = 'Campamento',
  List<ActivityAttendee> attendees = const [],
}) =>
    Activity(
      id: id,
      name: name,
      activityPlace: 'Parque Central',
      activityType: 1,
      platform: 0,
      active: true,
      clubSectionId: 1,
      clubTypeId: 2,
      activityDate: date ?? DateTime.now().add(const Duration(days: 3)),
      activityTime: '09:00',
      description: 'Trae tu mochila',
      attendeeProfiles: attendees,
    );
