/// The first-session therapeutic intake script. Like a therapist's first
/// appointment, it establishes WHO the person is, WHERE they are right now, what
/// is HARDEST, what they VALUE, what they want to ACCOMPLISH, and their READINESS
/// (Transtheoretical stage). The answers become the foundational memory profile
/// that every later interaction reads.
class IntakeStep {
  final String id; // field key
  final String prompt; // what Bloom asks
  final String hint; // shown under the text fallback
  const IntakeStep(this.id, this.prompt, this.hint);
}

const kIntakeScript = <IntakeStep>[
  IntakeStep('name', 'First — what should I call you?', 'your name or nickname'),
  IntakeStep('life',
      'Tell me a little about your life right now. What fills most of your days?',
      'work, study, family, a season of change…'),
  IntakeStep('feeling', 'And how have you been feeling lately, overall?',
      'however it really is'),
  IntakeStep('hardest', 'What feels hardest for you right now?',
      'the thing that weighs on you'),
  IntakeStep('value',
      'When you picture the person you want to become, what matters most to her?',
      'what you value / who you want to be'),
  IntakeStep('aspiration',
      'If you and I worked on one thing together, what would you most want to change or build?',
      'your first goal — broad is okay'),
  IntakeStep('readiness',
      'Last one. How ready do you feel to start — just exploring for now, or ready to take action?',
      'exploring / getting ready / ready to act'),
];
