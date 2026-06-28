import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/supabase/supabase_service.dart';
import 'data/sync/sync_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();   // no-op in local-only mode
  SyncEngine.instance.start();     // no-op until signed in
  runApp(const ProviderScope(child: BloomApp()));
}
