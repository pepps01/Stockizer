import 'package:flutter/material.dart';

import '../theme.dart';

/// Country flag from an ISO 3166 alpha-2 code, drawn as the emoji flag.
class Flag extends StatelessWidget {
  const Flag({super.key, required this.code, this.size = 24});

  final String code;
  final double size;

  static String emoji(String code) {
    final upper = code.toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(upper)) return '🏳️';
    return String.fromCharCodes(upper.codeUnits.map((c) => 0x1F1E6 + c - 0x41));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: context.palette.surfaceMuted, shape: BoxShape.circle),
      child: Text(emoji(code), style: TextStyle(fontSize: size * 0.62, height: 1.1)),
    );
  }
}
