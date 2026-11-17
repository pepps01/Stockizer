import 'package:flutter/material.dart';

import '../theme.dart';

/// Shows [items] a page at a time: [builder] draws the current page, and a
/// pager underneath gives previous / next, "7–12 of 22" and tappable dots.
/// With one page or fewer items there is no pager. [noun] names the items
/// for screen readers ("Next exchanges").
class PagedList<T> extends StatefulWidget {
  const PagedList({super.key, required this.items, required this.builder, required this.noun, this.pageSize = 6});

  final List<T> items;
  final Widget Function(BuildContext context, List<T> page) builder;
  final String noun;
  final int pageSize;

  @override
  State<PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<PagedList<T>> {
  int _page = 0;

  int get _pages => (widget.items.length / widget.pageSize).ceil();

  void _go(int page) => setState(() => _page = page.clamp(0, _pages - 1));

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final all = widget.items;
    if (_pages <= 1) return widget.builder(context, all);
    final page = _page.clamp(0, _pages - 1);
    final start = page * widget.pageSize;
    final end = (start + widget.pageSize).clamp(0, all.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.builder(context, all.sublist(start, end)),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              IconButton.outlined(
                tooltip: 'Previous ${widget.noun}',
                onPressed: page == 0 ? null : () => _go(page - 1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('${start + 1}–$end of ${all.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _pages; i++)
                          Semantics(
                            button: true,
                            label: 'Page ${i + 1}',
                            selected: i == page,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _go(i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: i == page ? 18 : 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: i == page ? p.foreground : p.border,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: 'Next ${widget.noun}',
                onPressed: page >= _pages - 1 ? null : () => _go(page + 1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
