import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'chip.dart';
import 'credencial_tokens.dart';
import 'credencial_view_model.dart';
import 'live_clock.dart';
import 'mini_field.dart';
import 'verified_dot.dart';

/// Tarjeta inmersiva — Variante B.
///
/// Gradiente diagonal + logo decorativo + foto/avatar + zona blanca con QR.
/// Recibe un [CredencialViewModel] construido desde [VirtualCard].
///
/// El QR embebido navega a [CredencialQrFullscreen] vía [onQrTap].
/// Pasar null en [onQrTap] deshabilita el tap (QR no disponible).
class CredencialCard extends StatelessWidget {
  final CredencialViewModel vm;
  final double qrSize; // 110 sm · 145 md · 175 lg
  final VoidCallback? onQrTap;

  const CredencialCard({
    super.key,
    required this.vm,
    this.qrSize = 145,
    this.onQrTap,
  });

  @override
  Widget build(BuildContext context) {
    final sec = Sec.of(vm.seccion);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CredencialTokens.rImmersive),
        gradient: LinearGradient(
          begin: const Alignment(-0.5, -1),
          end: const Alignment(0.5, 1),
          colors: [sec.primary, sec.primaryDark],
          stops: const [0.0, 0.75],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 36,
            offset: const Offset(0, 18),
            color: sec.primary.withAlpha(0x2B), // 17% per SPEC
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CredencialTokens.rImmersive),
        child: Stack(
          children: [
            // Logo gigante decorativo
            Positioned(
              right: -60,
              top: -40,
              child: Opacity(
                opacity: 0.10,
                child: Transform.rotate(
                  angle: -0.21, // ~-12°
                  child: Image.asset(sec.logo, width: 280, height: 280),
                ),
              ),
            ),
            // Sheen overlay diagonal
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(-1, -0.5),
                      end: const Alignment(1, 0.5),
                      colors: [
                        Colors.transparent,
                        Colors.white.withAlpha(0x2E), // ~18%
                        Colors.transparent,
                      ],
                      stops: const [0.35, 0.5, 0.65],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _topRow(sec),
                _identidad(sec),
                _zonaBlanca(context, sec),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _topRow(Sec sec) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Row(
        children: [
          Image.asset(sec.logo, width: 36, height: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sec.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '"${sec.motto}"',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withAlpha(0xBF), // ~75%
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(0x2E), // ~18%
              borderRadius: BorderRadius.circular(CredencialTokens.rChip),
              border: Border.all(
                color: Colors.white.withAlpha(0x40), // ~25%
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const VerifiedDot(size: 6),
                const SizedBox(width: 6),
                Text(
                  vm.estado == 'Activo' ? 'VIGENTE' : 'SUSPENDIDO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: vm.estado == 'Activo'
                        ? Colors.white
                        : CredencialTokens.dangerSoft,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _identidad(Sec sec) {
    final hasPhoto = vm.fotoUrl != null && vm.fotoUrl!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(0x1F), // ~12%
              boxShadow: [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  color: Colors.black.withAlpha(0x40), // ~25%
                ),
              ],
              border: Border.all(
                color: Colors.white.withAlpha(0x4D), // ~30%
              ),
            ),
            child: ClipOval(
              child: hasPhoto
                  ? Image.network(
                      vm.fotoUrl!,
                      fit: BoxFit.cover,
                      cacheWidth: 200,
                      errorBuilder: (_, __, ___) => _avatarFallback(sec),
                    )
                  : _avatarFallback(sec),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vm.nombre,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Chip primario: cargo si existe, sino sectionFull.
                    // Asegura que la zona de identidad nunca esté vacía cuando
                    // el backend aún no expone roleLabel.
                    if (vm.identidadPrimaria.isNotEmpty)
                      CredChip(label: vm.identidadPrimaria),
                    // Chip secundario: etapa si existe.
                    // Si no hay etapa pero sí cargo + sectionFull distintos,
                    // mostramos sectionFull como secundario (contexto extra).
                    if (vm.etapa.isNotEmpty)
                      CredChip(label: 'Etapa ${vm.etapa}')
                    else if (vm.cargo.isNotEmpty &&
                        vm.sectionFull.isNotEmpty &&
                        vm.cargo.toLowerCase() != vm.sectionFull.toLowerCase())
                      CredChip(label: vm.sectionFull),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(Sec sec) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [sec.accent, sec.primary],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        vm.iniciales,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: sec.primaryDark,
          letterSpacing: -0.4,
        ),
      ),
    );
  }

  Widget _zonaBlanca(BuildContext context, Sec sec) {
    String fmt(DateTime d) {
      const meses = [
        'ENE',
        'FEB',
        'MAR',
        'ABR',
        'MAY',
        'JUN',
        'JUL',
        'AGO',
        'SEP',
        'OCT',
        'NOV',
        'DIC',
      ];
      return '${d.day.toString().padLeft(2, '0')} ${meses[d.month - 1]} ${d.year}';
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF7FFFFFF), // .97 alpha
        border: Border(top: BorderSide(color: sec.accent, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onQrTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(CredencialTokens.rCard),
                    border: Border.all(color: CredencialTokens.borderLight),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        color: Colors.black.withAlpha(0x0F), // ~6%
                      ),
                    ],
                  ),
                  child: vm.qrData.isNotEmpty
                      ? QrImageView(
                          data: vm.qrData,
                          size: qrSize,
                          backgroundColor: Colors.white,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: sec.primaryDark,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: sec.primaryDark,
                          ),
                        )
                      : SizedBox(
                          width: qrSize,
                          height: qrSize,
                          child: const Center(
                            child: Icon(
                              Icons.qr_code_2_rounded,
                              size: 48,
                              color: Color(0xFF9AA0AB),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (vm.club.isNotEmpty || vm.sectionFull.isNotEmpty) ...[
                      Text(
                        // Si el clubName parece acrónimo (ej "ACV"), preferimos
                        // mostrar el nombre completo de la sección como label
                        // principal. Si no, mostramos CLUB normal.
                        vm.clubLooksLikeAcronym && vm.sectionFull.isNotEmpty
                            ? 'SECCIÓN'
                            : 'CLUB',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vm.clubLooksLikeAcronym && vm.sectionFull.isNotEmpty
                            ? vm.sectionFull
                            : vm.club,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: CredencialTokens.textPrimaryLight,
                          letterSpacing: -0.2,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // 2×2 mini-field grid per SPEC.
                    // Slot 2: blood type when available (from backend medical
                    // endpoint), otherwise section acronym as fallback.
                    // TODO: plumb tipoSangre from medical profile endpoint.
                    GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.9,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        MiniField(
                          label: 'VIGENTE',
                          value: fmt(vm.fechaVencimiento),
                        ),
                        // Slot 2: SANGRE if available, else SECCIÓN acronym.
                        vm.tipoSangre.isNotEmpty
                            ? MiniField(
                                label: 'SANGRE',
                                value: vm.tipoSangre,
                                highlight: CredencialTokens.danger,
                              )
                            : MiniField(
                                label: 'SECCIÓN',
                                value: vm.seccion.name,
                              ),
                        MiniField(
                          label: 'AÑO ECL.',
                          value: vm.anioEclesiastico,
                        ),
                        MiniField(
                          label: 'ESTADO',
                          value: vm.estado,
                          highlight: vm.estado == 'Activo'
                              ? CredencialTokens.success
                              : CredencialTokens.danger,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Footer institucional
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFE8EAEF), width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6B7280),
                        height: 1.35,
                      ),
                      children: [
                        TextSpan(
                          text: 'Iglesia Adventista del Séptimo Día\n',
                        ),
                        TextSpan(
                          text: 'Ministerio Juvenil',
                          style: TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'sacdia.org',
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      'v.${vm.idCorto}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        color: Color(0xFF9AA0AB),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    vm.folio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontFamily: 'monospace',
                      color: Color(0xFF9AA0AB),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LiveClock(
                    style: TextStyle(
                      fontSize: 9.5,
                      fontFamily: 'monospace',
                      color: Color(0xFF9AA0AB),
                    ),
                  ),
                  Text(
                    ' MX',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontFamily: 'monospace',
                      color: Color(0xFF9AA0AB),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
