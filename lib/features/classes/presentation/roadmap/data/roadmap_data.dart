// Modelos y datos mock del roadmap de clases SACDIA.
//
// Los IDs de las imágenes apuntan a assets/img/logos-clases/ que ya existe
// en el proyecto — no se duplican los PNGs.
//
// Los datos reales se obtienen via [roadmapTracksProvider] (Riverpod) usando
// [buildRoadmapTracks] para mapear List<ProgressiveClass> → List<TrackData>.
// [kRoadmapData] se conserva exclusivamente para tests y previews aislados.

import 'package:flutter/foundation.dart' show visibleForTesting;

enum ClassStatus {
  done,
  current,
  expired,
  notTaken,
  upcoming,
}

extension ClassStatusX on ClassStatus {
  bool get canOpenDetail =>
      this == ClassStatus.done ||
      this == ClassStatus.current ||
      this == ClassStatus.expired;
}

class ClassItem {
  final String id;
  final String name;
  final String age;
  final String img; // ej: 'assets/img/logos-clases/AV-01.png'
  final ClassStatus status;
  final int? enrollmentId;
  final double? progress; // 0..100, solo para 'current'
  final int? minimumAge;

  const ClassItem({
    required this.id,
    required this.name,
    required this.age,
    required this.img,
    required this.status,
    this.enrollmentId,
    this.progress,
    this.minimumAge,
  });
}

class TrackData {
  final String track; // 'Aventureros' | 'Conquistadores' | 'Guías Mayores'
  final String ageRange;
  final String accent; // hex string
  final String soft; // hex pastel
  final String kind; // 'av' | 'cq' | 'gm' (para sprites de fondo)
  final List<ClassItem> classes;

  const TrackData({
    required this.track,
    required this.ageRange,
    required this.accent,
    required this.soft,
    required this.kind,
    required this.classes,
  });
}

/// Datos mock del roadmap para tests y previews aislados.
/// En producción usar [roadmapTracksProvider] que conecta datos reales.
@visibleForTesting
const List<TrackData> kRoadmapData = [
  TrackData(
    track: 'Aventureros',
    ageRange: '6 — 9 años',
    accent: '#4FB37C',
    soft: '#E8F4EC',
    kind: 'av',
    classes: [
      ClassItem(
          id: 'av1',
          name: 'Corderitos',
          age: 'Desde 6 años',
          minimumAge: 6,
          img: 'assets/img/logos-clases/AV-01.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'av2',
          name: 'Aves Amigas',
          age: 'Desde 6 años',
          minimumAge: 6,
          img: 'assets/img/logos-clases/AV-02.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'av3',
          name: 'Abejitas Industriosas',
          age: 'Desde 7 años',
          minimumAge: 7,
          img: 'assets/img/logos-clases/AV-03.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'av4',
          name: 'Rayitos de Sol',
          age: 'Desde 7 años',
          minimumAge: 7,
          img: 'assets/img/logos-clases/AV-04.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'av5',
          name: 'Constructores',
          age: 'Desde 8 años',
          minimumAge: 8,
          img: 'assets/img/logos-clases/AV-05.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'av6',
          name: 'Manos Ayudadoras',
          age: 'Desde 9 años',
          minimumAge: 9,
          img: 'assets/img/logos-clases/AV-06.png',
          status: ClassStatus.done),
    ],
  ),
  TrackData(
    track: 'Conquistadores',
    ageRange: '10 — 15 años',
    accent: '#3D6FA5',
    soft: '#EAF1F8',
    kind: 'cq',
    classes: [
      ClassItem(
          id: 'cq1',
          name: 'Amigo',
          age: 'Desde 10 años',
          minimumAge: 10,
          img: 'assets/img/logos-clases/CQ-01.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'cq2',
          name: 'Compañero',
          age: 'Desde 11 años',
          minimumAge: 11,
          img: 'assets/img/logos-clases/CQ-02.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'cq3',
          name: 'Explorador',
          age: 'Desde 12 años',
          minimumAge: 12,
          img: 'assets/img/logos-clases/CQ-03.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'cq4',
          name: 'Orientador',
          age: 'Desde 13 años',
          minimumAge: 13,
          img: 'assets/img/logos-clases/CQ-04.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'cq5',
          name: 'Viajero',
          age: 'Desde 14 años',
          minimumAge: 14,
          img: 'assets/img/logos-clases/CQ-05.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'cq6',
          name: 'Guía',
          age: 'Desde 15 años',
          minimumAge: 15,
          img: 'assets/img/logos-clases/CQ-06.png',
          status: ClassStatus.done),
    ],
  ),
  TrackData(
    track: 'Guías Mayores',
    ageRange: '16+ años',
    accent: '#C99036',
    soft: '#FCF1DC',
    kind: 'gm',
    classes: [
      ClassItem(
          id: 'gm1',
          name: 'Guía Mayor',
          age: 'Desde 16 años',
          minimumAge: 16,
          img: 'assets/img/logos-clases/GM-01.png',
          status: ClassStatus.current,
          progress: 1),
      ClassItem(
          id: 'gm2',
          name: 'Máster',
          age: 'Desde 18 años',
          minimumAge: 18,
          img: 'assets/img/logos-clases/GM-02.png',
          status: ClassStatus.upcoming),
      ClassItem(
          id: 'gm3',
          name: 'Asesor',
          age: 'Desde 21 años',
          minimumAge: 21,
          img: 'assets/img/logos-clases/GM-03.png',
          status: ClassStatus.upcoming),
    ],
  ),
];
