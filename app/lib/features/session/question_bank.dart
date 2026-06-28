/// Offline adaptive-question bank. Mirrors the seeded `questions` table so the
/// daily check-in still works (calibrated, ordered) with no network / AI.
class BankQuestion {
  final String qId;
  final String question;
  final String comBFactor; // capability | opportunity | motivation | reflection
  final String? domain;
  const BankQuestion(this.qId, this.question, this.comBFactor, [this.domain]);
}

const kQuestionBank = <BankQuestion>[
  BankQuestion('open_today', 'How did today actually go for you?', 'reflection'),
  BankQuestion('goal_progress',
      'Thinking about your goal, what did you actually do toward it today?', 'reflection'),
  BankQuestion('obstacle', 'What got in the way, if anything?', 'reflection'),
  BankQuestion('mot_why', 'What would it mean for you if this really changed?', 'motivation'),
  BankQuestion('opp_context',
      "When in your day could this realistically fit tomorrow?", 'opportunity'),
  BankQuestion('win', "What's one small thing you're a little proud of today?", 'motivation'),
  BankQuestion('tomorrow_plan',
      "What's the one tiny step you want to set up for tomorrow?", 'opportunity'),
];
