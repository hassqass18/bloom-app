import '../../data/models/models2.dart';

/// Opt-in passive data sources (money / location / screen-time). Each is a
/// pluggable adapter so the core app never depends on it. All are OFF by default
/// and require explicit, revocable consent (see PrivacyScreen) plus — for the
/// live integrations — external credentials / platform permissions.
abstract class PassiveSource {
  /// Stable id matching a `consent_scope` (money | location | screen).
  String get id;
  String get label;

  /// Whether a working integration is wired (false = stub awaiting credentials).
  bool get available;

  /// Ask the OS / user for the permission this source needs.
  Future<bool> requestConsent();

  /// Pull any new signals since last sync. Stubs return an empty list.
  Future<List<PassiveSignal>> pull();
}

/// ⚠️ Bank / transaction sync. Needs a financial-aggregator account + API keys
/// (Plaid in the US; Mono / Stitch / Okra for Africa) and compliance review.
/// Until configured this is a no-op so the app stays complete and runnable.
class MoneySyncAdapter implements PassiveSource {
  @override
  String get id => 'money';
  @override
  String get label => 'Bank / transaction sync';
  @override
  bool get available => false; // set true once aggregator keys are provided
  @override
  Future<bool> requestConsent() async => false;
  @override
  Future<List<PassiveSignal>> pull() async => const [];
}

/// ⚠️ Location visit-detection (gym/home/etc.). Needs platform location
/// permission + a geofence/visit implementation; stubbed with manual fallback.
class LocationAdapter implements PassiveSource {
  @override
  String get id => 'location';
  @override
  String get label => 'Location visits';
  @override
  bool get available => false;
  @override
  Future<bool> requestConsent() async => false;
  @override
  Future<List<PassiveSignal>> pull() async => const [];
}

/// ⚠️ Screen-time / app-usage (constructive vs numbing). Needs Android
/// UsageStats / iOS Screen Time entitlements; stubbed with manual fallback.
class ScreenTimeAdapter implements PassiveSource {
  @override
  String get id => 'screen';
  @override
  String get label => 'Screen-time signals';
  @override
  bool get available => false;
  @override
  Future<bool> requestConsent() async => false;
  @override
  Future<List<PassiveSignal>> pull() async => const [];
}

/// The registry the app iterates over. Swap a stub for a real adapter when its
/// credentials/permissions are available — nothing else changes.
final List<PassiveSource> kPassiveSources = [
  MoneySyncAdapter(),
  LocationAdapter(),
  ScreenTimeAdapter(),
];
