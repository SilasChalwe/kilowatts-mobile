import 'package:flutter/material.dart';

import '../constants/asset_paths.dart';

class KilowattsLogo extends StatelessWidget {
  const KilowattsLogo({super.key, this.size = 112});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        AssetPaths.logo,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(Icons.bolt_rounded, size: size * 0.7),
      ),
    );
  }
}
