import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/bloom_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/models/models.dart';
import '../../providers.dart';

/// Budget — log spending/earning. (Bank sync + phone-activity metrics later.)
class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});
  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  final _uuid = const Uuid();
  final _amount = TextEditingController();
  final _category = TextEditingController();
  String _dir = 'spent';
  Future<Map<String, dynamic>>? _future;

  String get _month => DateTime.now().toIso8601String().substring(0, 7);

  @override
  void initState() {
    super.initState();
    _future = ref.read(entriesRepositoryProvider).monthMoney(_month);
  }

  @override
  void dispose() {
    _amount.dispose();
    _category.dispose();
    super.dispose();
  }

  void _refresh() =>
      setState(() => _future = ref.read(entriesRepositoryProvider).monthMoney(_month));

  Future<void> _add() async {
    final amt = double.tryParse(_amount.text.trim());
    if (amt == null || amt <= 0) return;
    final cat = _category.text.trim();
    _amount.clear();
    _category.clear();
    await ref.read(entriesRepositoryProvider).addMoney(MoneyEntry(
        id: _uuid.v4(), day: today(), direction: _dir, amount: amt,
        category: cat.isEmpty ? null : cat));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text('BUDGET', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Where your money goes — gently tracked.',
            style: TextStyle(color: BloomColors.whisper)),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            final spent = (snap.data?['spent'] as double?) ?? 0;
            final earned = (snap.data?['earned'] as double?) ?? 0;
            return Row(children: [
              _stat('Spent', spent),
              _stat('Earned', earned),
            ]);
          },
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add an entry', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              ChoiceChip(
                label: const Text('Spent'),
                selected: _dir == 'spent',
                onSelected: (_) => setState(() => _dir = 'spent'),
              ),
              ChoiceChip(
                label: const Text('Earned'),
                selected: _dir == 'earned',
                onSelected: (_) => setState(() => _dir = 'earned'),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'amount')),
            const SizedBox(height: 8),
            TextField(controller: _category,
                decoration: const InputDecoration(hintText: 'category (optional)')),
            const SizedBox(height: 8),
            FilledButton(onPressed: _add, child: const Text('ADD')),
          ]),
        ),
        const SizedBox(height: 12),
        const GlassCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.account_balance_outlined, color: BloomColors.whisper),
            title: Text('Connect your bank & phone activity'),
            subtitle: Text('Coming soon — with your permission, Bloom can auto-import transactions and use phone activity as a behavior signal.'),
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, double v) => Expanded(
        child: GlassCard(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(children: [
            Text(v.toStringAsFixed(0),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: BloomColors.gold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: BloomColors.whisper)),
          ]),
        ),
      );
}
