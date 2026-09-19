import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';

/// Avatar con foto de Steam (o inicial del nombre como respaldo).
///
/// Antes cada pantalla armaba esto a mano con `DecorationImage`, que no
/// tiene forma de reaccionar a un error de carga -- si la URL de la foto
/// fallaba (link roto, perfil borrado, CORS, lo que sea), el círculo
/// quedaba vacío en vez de caer al degradado + inicial. Bug real
/// reportado por el usuario ("el icono y el hueco"), reproducido con una
/// URL de avatar inválida. Acá la inicial siempre se pinta de base, y la
/// foto se dibuja encima solo si carga bien -- si falla, simplemente no
/// tapa la inicial.
class AvatarFoto extends StatelessWidget {
  final double size;
  final String? fotoUrl;
  final String inicial;
  final bool circular;
  final String? semanticLabel;
  final Color borderColor;
  final double borderWidth;

  const AvatarFoto({
    super.key,
    required this.size,
    required this.fotoUrl,
    required this.inicial,
    this.circular = true,
    this.semanticLabel,
    this.borderColor = SteamColors.blue,
    this.borderWidth = 1.5,
  });

  bool get _tieneFoto => fotoUrl != null && fotoUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final radius = circular
        ? BorderRadius.circular(size)
        : BorderRadius.circular(SteamRadii.sm);

    final contenido = ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [SteamColors.blue, SteamColors.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Center(
            child: Text(
              inicial,
              style: TextStyle(
                color: SteamColors.light,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (_tieneFoto)
            Image.network(
              fotoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const SizedBox.shrink(),
            ),
        ],
      ),
    );

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: contenido,
    );

    if (semanticLabel == null) return avatar;
    return Semantics(image: _tieneFoto, label: semanticLabel, child: avatar);
  }
}
