import 'package:bloom/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JournalEntry round-trips through local map', () {
    final e = JournalEntry(
      id: 'abc',
      day: '2026-06-26',
      kind: 'proud',
      payload: {'body': 'shipped Bloom'},
      words: 2,
    );
    final back = JournalEntry.fromMap(e.toMap());
    expect(back.id, e.id);
    expect(back.kind, 'proud');
    expect(back.payload['body'], 'shipped Bloom');
    expect(back.words, 2);
  });

  test('MoneyEntry parses amount and direction', () {
    final m = MoneyEntry(id: '1', day: '2026-06-26', direction: 'spent', amount: 250.5);
    final back = MoneyEntry.fromMap(m.toMap());
    expect(back.direction, 'spent');
    expect(back.amount, 250.5);
    expect(back.currency, 'KES');
  });
}
