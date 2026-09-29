import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../theme.dart';

class ActionButtons extends StatefulWidget {
  final String symbol;
  const ActionButtons({super.key, required this.symbol});

  @override
  State<ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<ActionButtons> {
  final _api = ApiClient();
  String? _pending;
  String? _confirmed;

  static const _actions = ['view', 'hold', 'buy', 'sell'];

  Color _colorFor(BuildContext context, String action) {
    if (action == 'buy') return AppColors.gain;
    if (action == 'sell') return AppColors.loss;
    return Theme.of(context).colorScheme.onSurface;
  }

  Future<void> _handleTap(String action) async {
    final auth = context.read<AuthProvider>();
    if (auth.token == null) {
      Navigator.of(context).pushNamed('/login');
      return;
    }
    setState(() => _pending = action);
    try {
      await _api.recordSelectorAction(auth.token!, symbol: widget.symbol, action: action);
      setState(() => _confirmed = action);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _confirmed = null);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to record action')));
      }
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: _actions.map((action) {
        final color = _colorFor(context, action);
        final isConfirmed = _confirmed == action;
        return OutlinedButton(
          onPressed: _pending == action ? null : () => _handleTap(action),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(isConfirmed ? 'Saved' : action[0].toUpperCase() + action.substring(1)),
        );
      }).toList(),
    );
  }
}
