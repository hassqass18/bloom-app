/// Best-effort gender guess from a first name (Bloom serves men and women).
/// Returns 'male', 'female', or null when unsure. Intentionally light: Bloom
/// stays warm/neutral and the cloud AI uses this only as a soft hint. When null,
/// the experience simply stays neutral.
String? guessGender(String? name) {
  if (name == null) return null;
  final n = name.trim().toLowerCase().split(RegExp(r'[\s,]')).first;
  if (n.isEmpty) return null;
  if (_female.contains(n)) return 'female';
  if (_male.contains(n)) return 'male';
  // weak fallback on common endings (very rough)
  if (n.endsWith('a') || n.endsWith('ah') || n.endsWith('ia') || n.endsWith('ine')) {
    return 'female';
  }
  return null;
}

// Compact, multicultural seed lists (Western, African, Arabic, etc.).
const _female = <String>{
  'khadija', 'khadijah', 'fatima', 'fatma', 'aisha', 'ayesha', 'amina', 'zainab',
  'mary', 'maria', 'sarah', 'sara', 'hannah', 'grace', 'faith', 'joy', 'esther',
  'ruth', 'rebecca', 'rachel', 'leah', 'naomi', 'hope', 'rose', 'lily', 'ada',
  'amara', 'zara', 'nia', 'imani', 'asha', 'wanjiru', 'wambui', 'akinyi', 'njeri',
  'chiamaka', 'ngozi', 'adaeze', 'amani', 'halima', 'maryam', 'layla', 'leila',
  'emily', 'olivia', 'sophia', 'ava', 'mia', 'isabella', 'amelia', 'charlotte',
  'aaliyah', 'destiny', 'jada', 'keisha', 'tiana', 'maya', 'zoe', 'naya', 'kira',
};

const _male = <String>{
  'mohammed', 'muhammad', 'ahmed', 'ali', 'omar', 'hassan', 'hussein', 'ibrahim',
  'yusuf', 'idris', 'bilal', 'tariq', 'malik', 'jamal', 'kareem', 'rashid',
  'john', 'james', 'david', 'michael', 'joseph', 'daniel', 'samuel', 'peter',
  'paul', 'mark', 'luke', 'matthew', 'isaac', 'jacob', 'noah', 'elijah', 'caleb',
  'kwame', 'kofi', 'kwesi', 'chidi', 'emeka', 'obi', 'tunde', 'femi', 'sefu',
  'juma', 'baraka', 'jelani', 'kato', 'musa', 'amir', 'zaid', 'yahya',
  'william', 'liam', 'ethan', 'mason', 'logan', 'lucas', 'jackson', 'aiden',
  'andre', 'darius', 'marcus', 'deshawn', 'tyrone', 'xavier', 'malcolm', 'isaiah',
};
