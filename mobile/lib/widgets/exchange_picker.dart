import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/market.dart';
import '../services/api_client.dart';
import '../theme.dart';
import 'badges.dart';
import 'common.dart';
import 'flag.dart';

/// Form field that picks an exchange code from a searchable bottom sheet.
class ExchangePickerField extends StatefulWidget {
  const ExchangePickerField({super.key, required this.value, required this.onChanged, this.allowNone = false});

  final String? value;
  final ValueChanged<String?> onChanged;

  /// Offer a "No default" entry (profile's default exchange).
  final bool allowNone;

  @override
  State<ExchangePickerField> createState() => _ExchangePickerFieldState();
}

class _ExchangePickerFieldState extends State<ExchangePickerField> {
  late final Future<List<Exchange>> _exchanges = context.read<ApiClient>().exchanges();

  Future<void> _pick(List<Exchange> exchanges) async {
    final picked = await showModalBottomSheet<_Pick>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExchangeSheet(exchanges: exchanges, allowNone: widget.allowNone, selected: widget.value),
    );
    if (picked != null) widget.onChanged(picked.code);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FutureBuilder<List<Exchange>>(
      future: _exchanges,
      builder: (context, snapshot) {
        final exchanges = snapshot.data ?? const <Exchange>[];
        final selected = exchanges.where((e) => e.code == widget.value).firstOrNull;
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: snapshot.hasData ? () => _pick(exchanges) : null,
          child: InputDecorator(
            decoration: InputDecoration(
              suffixIcon: snapshot.hasError
                  ? Icon(Icons.error_outline, color: p.loss)
                  : (snapshot.hasData ? const Icon(Icons.expand_more) : const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))),
            ),
            child: selected == null
                ? Text(
                    snapshot.hasError ? errorMessage(snapshot.error) : (widget.value ?? (widget.allowNone ? 'No default' : 'Choose an exchange')),
                    style: TextStyle(color: p.mutedForeground),
                  )
                : Row(
                    children: [
                      Flag(code: selected.countryCode, size: 22),
                      const SizedBox(width: 8),
                      Text(selected.code, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(selected.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mutedForeground))),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _Pick {
  const _Pick(this.code);
  final String? code;
}

class _ExchangeSheet extends StatefulWidget {
  const _ExchangeSheet({required this.exchanges, required this.allowNone, required this.selected});

  final List<Exchange> exchanges;
  final bool allowNone;
  final String? selected;

  @override
  State<_ExchangeSheet> createState() => _ExchangeSheetState();
}

class _ExchangeSheetState extends State<_ExchangeSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = _query.toLowerCase();
    final matches = widget.exchanges
        .where((e) => q.isEmpty || '${e.code} ${e.name} ${e.country}'.toLowerCase().contains(q))
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: false,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search exchange or country'),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (widget.allowNone)
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: const Text('No default'),
                    onTap: () => Navigator.pop(context, const _Pick(null)),
                  ),
                for (final e in matches)
                  ListTile(
                    leading: Flag(code: e.countryCode, size: 32),
                    title: Row(
                      children: [
                        Text(e.code, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        SourceBadge(source: e.dataSource),
                      ],
                    ),
                    subtitle: Text('${e.name} · ${e.country}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: e.code == widget.selected ? Icon(Icons.check, color: p.brand) : null,
                    onTap: () => Navigator.pop(context, _Pick(e.code)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
