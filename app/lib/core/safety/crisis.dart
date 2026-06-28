import 'package:flutter/material.dart';

/// Lightweight on-device crisis screen. Bloom is a wellness companion, NOT a
/// medical device — when distress signals appear, we stop coaching and surface
/// real help (locale-aware). This never diagnoses or treats.
class Crisis {
  static final _patterns = <RegExp>[
    RegExp(r'\b(kill myself|end my life|suicid|don.?t want to live|want to die)\b',
        caseSensitive: false),
    RegExp(r'\b(hurt myself|harm myself|self.?harm|cut myself)\b', caseSensitive: false),
    RegExp(r"\b(no reason to live|better off dead|can.?t go on)\b", caseSensitive: false),
  ];

  static bool looksLikeCrisis(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    return _patterns.any((p) => p.hasMatch(text));
  }

  static const resources = <Map<String, String>>[
    {'name': 'Befrienders Kenya', 'contact': '+254 722 178 177'},
    {'name': 'Kenya Red Cross (free)', 'contact': '1199'},
    {'name': 'Emergency services', 'contact': '999 / 112'},
    {'name': 'Find a helpline (global)', 'contact': 'findahelpline.com'},
  ];

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You matter. 💜',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              "It sounds like you're carrying something really heavy. Bloom isn't a "
              "substitute for a person — please reach out to someone who can help right now.",
            ),
            const SizedBox(height: 16),
            ...resources.map((r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.favorite_outline),
                  title: Text(r['name']!),
                  trailing: Text(r['contact']!,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                )),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
