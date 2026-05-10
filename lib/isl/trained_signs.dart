class ISLTrainedSign {
  final String label;
  final String symptom;

  const ISLTrainedSign({required this.label, required this.symptom});
}

class ISLTrainedSigns {
  static const String noSignLabel = 'NO-SIGN';

  static const List<ISLTrainedSign> signs = [
    ISLTrainedSign(label: 'BUKHAR', symptom: 'fever'),
    ISLTrainedSign(label: 'PET-DARD', symptom: 'stomach pain'),
    ISLTrainedSign(label: 'SANS-TAKLEEF', symptom: 'breathlessness'),
    ISLTrainedSign(label: 'SAR-DARD', symptom: 'headache'),
  ];

  static const List<ISLTrainedSign> collectionSigns = [
    ...signs,
    ISLTrainedSign(label: noSignLabel, symptom: 'no symptom / background'),
  ];

  static const Set<String> labels = {
    'BUKHAR',
    'PET-DARD',
    'SANS-TAKLEEF',
    'SAR-DARD',
    noSignLabel,
  };

  static const Map<String, String> symptomsByLabel = {
    'BUKHAR': 'fever',
    'PET-DARD': 'stomach pain',
    'SANS-TAKLEEF': 'breathlessness',
    'SAR-DARD': 'headache',
  };

  static bool isTrainedLabel(String label) => labels.contains(label);

  static bool isNoSignLabel(String label) => label == noSignLabel;

  static String? symptomFor(String label) => symptomsByLabel[label];

  static String displayTextFor(String label) {
    for (final sign in collectionSigns) {
      if (sign.label == label) return sign.symptom;
    }
    return 'unknown';
  }
}
