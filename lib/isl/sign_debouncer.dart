class SignDebouncer {
  final int windowSize;
  final int minVotes;
  final Duration repeatCooldown;

  final List<String> _recent = [];
  String? _lastEmittedSign;
  DateTime? _lastEmitTime;

  SignDebouncer({
    this.windowSize = 6,
    this.minVotes = 4,
    this.repeatCooldown = const Duration(milliseconds: 1400),
  });

  String? process(String candidate) {
    _recent.add(candidate);
    if (_recent.length > windowSize) _recent.removeAt(0);

    final votes = _recent.where((sign) => sign == candidate).length;
    if (votes < minVotes) return null;

    final now = DateTime.now();
    if (_lastEmittedSign == candidate && _lastEmitTime != null) {
      final elapsed = now.difference(_lastEmitTime!);
      if (elapsed < repeatCooldown) return null;
    }

    _lastEmittedSign = candidate;
    _lastEmitTime = now;
    _recent.clear();
    return candidate;
  }

  void reset() {
    _recent.clear();
    _lastEmittedSign = null;
    _lastEmitTime = null;
  }
}
