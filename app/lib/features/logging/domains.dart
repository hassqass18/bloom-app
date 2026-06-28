/// Holistic life domains for all-encompassing logging — answering the
/// conversation's "life is encompassing… workout, eating, spending, family,
/// reading, mental breaks". Used to tag logs and pick adaptive questions.
class LifeDomain {
  final String key;
  final String label;
  final String emoji;
  const LifeDomain(this.key, this.label, this.emoji);
}

const kLifeDomains = <LifeDomain>[
  LifeDomain('mood', 'Mood & feelings', '💗'),
  LifeDomain('money', 'Money & spending', '💰'),
  LifeDomain('movement', 'Movement & gym', '🏃‍♀️'),
  LifeDomain('food', 'Food & eating', '🍎'),
  LifeDomain('family', 'Family & relationships', '👨‍👩‍👧'),
  LifeDomain('reading', 'Reading & learning', '📚'),
  LifeDomain('screen', 'Screen & time-use', '📱'),
  LifeDomain('rest', 'Rest & mental breaks', '🌙'),
  LifeDomain('faith', 'Faith & meaning', '🕊️'),
  LifeDomain('work', 'Work & productivity', '💼'),
];
