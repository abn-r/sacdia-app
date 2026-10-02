import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/virtual_card/domain/entities/virtual_card.dart';
import 'package:sacdia_app/features/virtual_card/presentation/widgets/credencial/credencial_tokens.dart';
import 'package:sacdia_app/features/virtual_card/presentation/widgets/credencial/credencial_view_model.dart';

VirtualCard _card({
  String? clubName,
  String? sectionName,
  String? roleCode,
}) {
  return VirtualCard(
    userId: 'user-1',
    fullName: 'Ana Lopez',
    qrToken: 'token',
    qrExpiresAt: DateTime.utc(2099, 1, 1),
    isActive: true,
    clubName: clubName,
    sectionName: sectionName,
    roleCode: roleCode,
  );
}

void main() {
  group('CredencialViewModel', () {
    test(
        'should paint Guías Mayores when section is GM even if club name has Aventureros',
        () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(
          clubName: 'Club Aventureros Central',
          sectionName: 'Guías Mayores',
        ),
      );

      expect(vm.seccion, SeccionCode.GM);
    });

    test('should paint Aventureros when identity section is Aventureros', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(sectionName: 'Aventureros'),
      );

      expect(vm.seccion, SeccionCode.AV);
    });

    test('vigencia is the ecclesiastical year from the card', () {
      final vm = CredencialViewModel.fromVirtualCard(
        VirtualCard(
          userId: 'user-1',
          fullName: 'Ana Lopez',
          qrToken: 'token',
          qrExpiresAt: DateTime.utc(2099, 10, 1),
          isActive: true,
          clubName: 'ACV',
          localFieldName: 'Campo Centro',
          unionName: 'Unión Norte',
          ecclesiasticalYear: '2026',
        ),
      );

      expect(vm.anioEclesiastico, '2026');
      expect(vm.campoLocal, 'Campo Centro');
      expect(vm.unionNombre, 'Unión Norte');
      expect(vm.club, 'ACV');
    });

    test('should paint Conquistadores from section name', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(sectionName: 'Conquistadores'),
      );

      expect(vm.seccion, SeccionCode.CQ);
    });
  });
}
