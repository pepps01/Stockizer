import 'package:flutter/material.dart';

import '../theme.dart';
import 'flag.dart';

/// A ticker's mark: the company logo in a white circle with a small country
/// flag on its corner. Without a logo (simulated stocks, indices, a failed
/// load) it falls back to the country flag, or the symbol's first letters.
class TickerLogo extends StatelessWidget {
  const TickerLogo({super.key, required this.symbol, this.logoUrl, this.countryCode, this.size = 40, this.badge = true});

  final String symbol;
  final String? logoUrl;
  final String? countryCode;
  final double size;

  /// Show the country flag badge on the logo.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    if (url == null || url.isEmpty) return _fallback(context);
    final p = context.palette;
    final logo = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: p.border),
      ),
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, _, _) => _fallback(context, inset: true),
          frameBuilder: (context, child, frame, sync) => sync || frame != null ? child : _fallback(context, inset: true),
        ),
      ),
    );
    final code = countryCode;
    if (!badge || code == null || code.isEmpty) return Semantics(label: symbol, child: logo);
    final flag = size * 0.42;
    return Semantics(
      label: symbol,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            logo,
            Positioned(
              right: -flag * 0.18,
              bottom: -flag * 0.18,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: p.surface, width: 1.5),
                ),
                child: Flag(code: code, size: flag),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context, {bool inset = false}) {
    final code = countryCode;
    if (!inset && code != null && code.isNotEmpty) return Flag(code: code, size: size);
    final p = context.palette;
    final letters = symbol.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final text = letters.substring(0, letters.length < 2 ? letters.length : 2).toUpperCase();
    return Container(
      width: inset ? null : size,
      height: inset ? null : size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.surfaceMuted, shape: BoxShape.circle),
      child: Text(
        text,
        style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.w900, color: p.foreground),
      ),
    );
  }
}
