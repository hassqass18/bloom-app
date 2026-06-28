import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/models2.dart';
import '../../providers.dart';

/// Privacy by design: granular, revocable consent for AI + passive data sources,
/// plus data export and full local wipe. Bloom is on-device first.
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  static const _scopes = {
    'ai': 'AI companion (sends entries to the AI to personalise insights)',
    'measures': 'Validated wellbeing check-ins (WHO-5)',
    'money': 'Bank / transaction sync (auto money logging)',
    'location': 'Location (visit detection: gym, home…)',
    'screen': 'Screen-time / app-usage signals',
  };
  final Map<String, bool> _granted = {};
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(entriesRepositoryProvider);
    for (final s in _scopes.keys) {
      final c = await repo.consentFor(s);
      _granted[s] = c?.granted ?? false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _set(String scope, bool v) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await ref.read(entriesRepositoryProvider).setConsent(Consent(
          id: _uuid.v4(),
          scope: scope,
          granted: v,
          grantedAt: v ? now : null,
          revokedAt: v ? null : now,
        ));
    setState(() => _granted[scope] = v);
  }

  Future<void> _export() async {
    final data = await ref.read(entriesRepositoryProvider).exportAll();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'bloom_export_${DateTime.now().millisecondsSinceEpoch}.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Exported to ${file.path}')));
    }
  }

  Future<void> _wipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Erase everything on this device?'),
        content: const Text(
            'This permanently deletes all your local Bloom data. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Erase')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(entriesRepositoryProvider).wipeAll();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('All local data erased.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Your data stays on your device unless you turn things on.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          ..._scopes.entries.map((e) => Card(
                child: SwitchListTile(
                  value: _granted[e.key] ?? false,
                  onChanged: (v) => _set(e.key, v),
                  title: Text(e.key.toUpperCase()),
                  subtitle: Text(e.value, style: const TextStyle(fontSize: 12)),
                ),
              )),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _export,
            icon: const Icon(Icons.download),
            label: const Text('Export my data (JSON)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _wipe,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Erase all local data'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bloom is a wellness & self-development companion — not a medical device '
            'or a replacement for therapy. If you are in crisis, please contact local '
            'emergency services or a crisis line.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
