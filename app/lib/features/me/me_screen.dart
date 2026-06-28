import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/supabase/supabase_service.dart';
import '../../core/widgets/glass_card.dart';
import '../../providers.dart';
import '../insights/insights_screen.dart';
import '../money/money_screen.dart';
import '../privacy/privacy_screen.dart';
import '../timeline/timeline_screen.dart';

/// Account, status, and the secondary surfaces (timeline, money, insights, privacy).
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(entriesRepositoryProvider);
    void open(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Me', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Timeline'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(const TimelineScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Money'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(const MoneyScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text('Weekly insights'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(const InsightsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy & data'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(const PrivacyScreen()),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Sync'),
          subtitle: Text(!Env.hasCloud
              ? 'Local-only mode (no cloud configured)'
              : SupabaseService.isSignedIn
                  ? 'Signed in — syncing'
                  : 'Signed out'),
        ),
        FutureBuilder<int>(
          future: repo.pendingSyncCount(),
          builder: (context, snap) => ListTile(
            leading: const Icon(Icons.sync_outlined),
            title: const Text('Pending to sync'),
            trailing: Text('${snap.data ?? 0}'),
          ),
        ),
        if (Env.hasCloud && SupabaseService.isSignedIn)
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => SupabaseService.signOut(),
          ),
        const ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('Your entries are private'),
          subtitle: Text('On-device first. AI is optional. Only you can read them.'),
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Bloom is a wellness & self-development companion — not a medical device '
            'or a replacement for therapy.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
