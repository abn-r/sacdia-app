import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/virtual_card/domain/entities/virtual_card.dart';
import 'package:sacdia_app/features/virtual_card/presentation/widgets/credencial/credencial_tokens.dart';
import 'package:sacdia_app/features/virtual_card/presentation/widgets/credencial/credencial_view_model.dart';

VirtualCard _card({
  String userId = 'user-123',
  String fullName = 'Abner Reyes Ramirez',
  String? photoUrl,
  String? roleLabel,
  String? roleCode,
  String? clubName,
  String? sectionName,
  String? cardIdShort,
  String? qrToken = 'eyJhbGciOiJIUzI1NiJ9.payloadXY.signatureABCDEF12345',
  DateTime? qrExpiresAt,
  bool isActive = true,
  bool isOffline = false,
  String? currentClass,
  String? bloodType,
  EmergencyContact? emergencyContact,
}) {
  return VirtualCard(
    userId: userId,
    fullName: fullName,
    photoUrl: photoUrl,
    roleLabel: roleLabel,
    roleCode: roleCode,
    clubName: clubName,
    sectionName: sectionName,
    cardIdShort: cardIdShort,
    qrToken: qrToken,
    qrExpiresAt: qrExpiresAt ?? DateTime.utc(2027, 1, 15),
    isActive: isActive,
    isOffline: isOffline,
    currentClass: currentClass,
    bloodType: bloodType,
    emergencyContact: emergencyContact,
  );
}

void main() {
  group('CredencialViewModel.fromVirtualCard - section detection', () {
    test('detects AV from clubName containing "aventur"', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(clubName: 'Club Aventureros del Camino'),
      );
      expect(vm.seccion, SeccionCode.AV);
    });

    test('detects CQ from clubName containing "conq"', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(clubName: 'Club Conquistadores del Norte'),
      );
      expect(vm.seccion, SeccionCode.CQ);
    });

    test('detects GM from sectionName containing "guia"', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(sectionName: 'Guías Mayores'),
      );
      expect(vm.seccion, SeccionCode.GM);
    });

    test('detects GM from sectionName containing "mayor"', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(sectionName: 'Guias Mayores Avanzados'),
      );
      expect(vm.seccion, SeccionCode.GM);
    });

    test('defaults to CQ when nothing matches', () {
      final vm = CredencialViewModel.fromVirtualCard(_card());
      expect(vm.seccion, SeccionCode.CQ);
    });

    test('uses roleCode as additional source for matching', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(roleCode: 'aventureros_director'),
      );
      expect(vm.seccion, SeccionCode.AV);
    });
  });

  group('CredencialViewModel.fromVirtualCard - club acronym', () {
    test('builds 3-letter acronym from multi-word clubName', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(clubName: 'Aguilas Camino Vencido'),
      );
      expect(vm.clubCorto, 'ACV');
    });

    test('truncates to 3 letters when more than 3 words', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(clubName: 'Aguilas Del Camino Vencido'),
      );
      expect(vm.clubCorto, 'ADC');
    });

    test('uppercases first letter for single-word clubName', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(clubName: 'Esperanza'),
      );
      expect(vm.clubCorto, 'E');
    });

    test('falls back to first 3 chars of sectionName when clubName empty', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(sectionName: 'Aventureros'),
      );
      expect(vm.clubCorto, 'AVE');
    });

    test('falls back to "CLB" when both empty', () {
      final vm = CredencialViewModel.fromVirtualCard(_card());
      expect(vm.clubCorto, 'CLB');
    });
  });

  group('CredencialViewModel.clubLooksLikeAcronym', () {
    test('returns true for 4-char club name', () {
      final vm = CredencialViewModel.fromVirtualCard(_card(clubName: 'ACVA'));
      expect(vm.clubLooksLikeAcronym, isTrue);
    });

    test('returns true for 3-char club name', () {
      final vm = CredencialViewModel.fromVirtualCard(_card(clubName: 'ACV'));
      expect(vm.clubLooksLikeAcronym, isTrue);
    });

    test('returns false for full club name', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(clubName: 'Aguilas Camino Vencido'),
      );
      expect(vm.clubLooksLikeAcronym, isFalse);
    });

    test('returns true for empty club name', () {
      final vm = CredencialViewModel.fromVirtualCard(_card());
      expect(vm.clubLooksLikeAcronym, isTrue);
    });
  });

  group('CredencialViewModel.identidadPrimaria - chip fallback', () {
    test('uses cargo when present', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(roleLabel: 'Director', sectionName: 'Guías Mayores'),
      );
      expect(vm.identidadPrimaria, 'Director');
    });

    test('falls back to sectionFull when cargo empty', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(sectionName: 'Guías Mayores'),
      );
      expect(vm.identidadPrimaria, 'Guías Mayores');
    });

    test('returns empty when both missing', () {
      final vm = CredencialViewModel.fromVirtualCard(_card());
      expect(vm.identidadPrimaria, '');
    });
  });

  group('CredencialViewModel.iniciales', () {
    test('builds initials from first 2 words', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(fullName: 'Abner Reyes Ramirez'),
      );
      expect(vm.iniciales, 'AR');
    });

    test('uses single letter for single-word name', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(fullName: 'Madonna'),
      );
      expect(vm.iniciales, 'M');
    });

    test('returns "?" for empty fullName (falls back to "Miembro")', () {
      final vm = CredencialViewModel.fromVirtualCard(_card(fullName: ''));
      // fullName empty falls back to 'Miembro' in the factory
      expect(vm.nombre, 'Miembro');
      expect(vm.iniciales, 'M');
    });

    test('handles extra whitespace between words', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(fullName: 'Abner   Reyes'),
      );
      expect(vm.iniciales, 'AR');
    });
  });

  group('CredencialViewModel.fromVirtualCard - folio derivation', () {
    test('uses cardIdShort when present', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(cardIdShort: 'fd43191d'),
      );
      expect(vm.folio, startsWith('SAC-'));
      expect(vm.folio, contains('FD43191D'));
    });

    test('falls back to last 8 chars of token formatted', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(
          cardIdShort: null,
          qrToken: 'eyJhbGciOiJIUzI1NiJ9.payload.SignAB12345678',
          qrExpiresAt: DateTime.utc(2027, 6, 1),
        ),
      );
      // Suffix = '12345678' → SAC-2027-1234-5678
      expect(vm.folio, 'SAC-2027-1234-5678');
      expect(vm.folio, matches(RegExp(r'^SAC-\d{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$')));
    });
  });

  group('CredencialViewModel.fromVirtualCard - idCorto', () {
    test('uses last 8 chars of cardIdShort lowercased', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(cardIdShort: 'FD43191D'),
      );
      expect(vm.idCorto, 'fd43191d');
    });

    test('pads short cardIdShort to 8 chars with zeros', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(cardIdShort: 'AB12'),
      );
      expect(vm.idCorto.length, 8);
      expect(vm.idCorto, endsWith('ab12'));
    });

    test('falls back to last 8 chars of token when no cardIdShort', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(cardIdShort: null, qrToken: 'tokenSuffixIsHEREEEE12345678'),
      );
      expect(vm.idCorto.length, 8);
    });
  });

  group('CredencialViewModel.fromVirtualCard - estado', () {
    test('Activo when isActive true', () {
      final vm = CredencialViewModel.fromVirtualCard(_card(isActive: true));
      expect(vm.estado, 'Activo');
    });

    test('Suspendido when isActive false', () {
      final vm = CredencialViewModel.fromVirtualCard(_card(isActive: false));
      expect(vm.estado, 'Suspendido');
    });
  });

  group('CredencialViewModel.fromVirtualCard - dates', () {
    test('uses qrExpiresAt when present', () {
      final fecha = DateTime.utc(2026, 12, 31);
      final vm = CredencialViewModel.fromVirtualCard(
        _card(qrExpiresAt: fecha),
      );
      expect(vm.fechaVencimiento, fecha);
    });

    test('anioEclesiastico is current year as string', () {
      final vm = CredencialViewModel.fromVirtualCard(_card());
      expect(vm.anioEclesiastico, DateTime.now().year.toString());
    });
  });

  group('CredencialViewModel.fromVirtualCard - new backend fields', () {
    test('maps currentClass to etapa', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(currentClass: 'Compañero'),
      );
      expect(vm.etapa, 'Compañero');
    });

    test('etapa empty when currentClass null', () {
      final vm = CredencialViewModel.fromVirtualCard(_card());
      expect(vm.etapa, '');
    });

    test('maps bloodType to tipoSangre', () {
      final vm = CredencialViewModel.fromVirtualCard(_card(bloodType: 'O+'));
      expect(vm.tipoSangre, 'O+');
    });

    test('tipoSangre empty when bloodType null', () {
      final vm = CredencialViewModel.fromVirtualCard(_card());
      expect(vm.tipoSangre, '');
    });

    test('maps emergencyContact fields', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(
          emergencyContact: const EmergencyContact(
            name: 'Maria Lopez',
            phone: '+5215512345678',
            relationship: 'Madre',
          ),
        ),
      );
      expect(vm.emergenciaNombre, 'Maria Lopez');
      expect(vm.emergenciaTel, '+5215512345678');
      expect(vm.emergenciaRelacion, 'Madre');
      expect(vm.hasEmergencia, isTrue);
    });

    test('hasEmergencia false when contact null', () {
      final vm = CredencialViewModel.fromVirtualCard(_card());
      expect(vm.hasEmergencia, isFalse);
      expect(vm.emergenciaNombre, '');
      expect(vm.emergenciaTel, '');
      expect(vm.emergenciaRelacion, '');
    });

    test('hasEmergencia false when only name present', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(
          emergencyContact: const EmergencyContact(
            name: 'X',
            phone: '',
            relationship: 'Madre',
          ),
        ),
      );
      expect(vm.hasEmergencia, isFalse);
    });
  });

  group('CredencialViewModel.fromVirtualCard - identity passthrough', () {
    test('passes nombre, club, sectionFull, fotoUrl', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(
          fullName: 'Abner Reyes',
          clubName: 'Aguilas Camino Vencido',
          sectionName: 'Guías Mayores',
          photoUrl: 'https://r2/avatars/abc.jpg',
        ),
      );
      expect(vm.nombre, 'Abner Reyes');
      expect(vm.club, 'Aguilas Camino Vencido');
      expect(vm.sectionFull, 'Guías Mayores');
      expect(vm.fotoUrl, 'https://r2/avatars/abc.jpg');
    });

    test('qrData equals card.qrToken', () {
      final vm = CredencialViewModel.fromVirtualCard(
        _card(qrToken: 'mytoken.abc.123'),
      );
      expect(vm.qrData, 'mytoken.abc.123');
    });

    test('qrData empty string when qrToken null', () {
      final vm = CredencialViewModel.fromVirtualCard(_card(qrToken: null));
      expect(vm.qrData, '');
    });
  });
}
