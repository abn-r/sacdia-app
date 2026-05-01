// Modelos y datos mock del roadmap de clases SACDIA.
//
// Los IDs de las imágenes apuntan a assets/img/logos-clases/ que ya existe
// en el proyecto — no se duplican los PNGs.
//
// Los datos reales se obtienen via [roadmapTracksProvider] (Riverpod) usando
// [buildRoadmapTracks] para mapear List<ProgressiveClass> → List<TrackData>.
// [kRoadmapData] se conserva exclusivamente para tests y previews aislados.

import 'package:flutter/foundation.dart' show visibleForTesting;

enum ClassStatus { done, current, locked }

class ClassItem {
  final String id;
  final String name;
  final String age;
  final String img; // ej: 'assets/img/logos-clases/AV-01.png'
  final ClassStatus status;
  final double? progress; // 0..100, solo para 'current'

  const ClassItem({
    required this.id,
    required this.name,
    required this.age,
    required this.img,
    required this.status,
    this.progress,
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
          age: '6 años',
          img: 'assets/img/logos-clases/AV-01.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'av2',
          name: 'Aves Amigas',
          age: '6 años',
          img: 'assets/img/logos-clases/AV-02.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'av3',
          name: 'Abejitas Industriosas',
          age: '7 años',
          img: 'assets/img/logos-clases/AV-03.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'av4',
          name: 'Rayitos de Sol',
          age: '7 años',
          img: 'assets/img/logos-clases/AV-04.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'av5',
          name: 'Constructores',
          age: '8 años',
          img: 'assets/img/logos-clases/AV-05.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'av6',
          name: 'Manos Ayudadoras',
          age: '9 años',
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
          age: '10 años',
          img: 'assets/img/logos-clases/CQ-01.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'cq2',
          name: 'Compañero',
          age: '11 años',
          img: 'assets/img/logos-clases/CQ-02.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'cq3',
          name: 'Explorador',
          age: '12 años',
          img: 'assets/img/logos-clases/CQ-03.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'cq4',
          name: 'Orientador',
          age: '13 años',
          img: 'assets/img/logos-clases/CQ-04.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'cq5',
          name: 'Viajero',
          age: '14 años',
          img: 'assets/img/logos-clases/CQ-05.png',
          status: ClassStatus.done),
      ClassItem(
          id: 'cq6',
          name: 'Guía',
          age: '15 años',
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
          age: '16+ años',
          img: 'assets/img/logos-clases/GM-01.png',
          status: ClassStatus.current,
          progress: 1),
      ClassItem(
          id: 'gm2',
          name: 'Máster',
          age: '18+ años',
          img: 'assets/img/logos-clases/GM-02.png',
          status: ClassStatus.locked),
      ClassItem(
          id: 'gm3',
          name: 'Asesor',
          age: '21+ años',
          img: 'assets/img/logos-clases/GM-03.png',
          status: ClassStatus.locked),
    ],
  ),
];
