class UserProgress {
  final int exp;

  const UserProgress({this.exp = 0});

  int get level {
    // Progressive leveling: base 100, +50 per level increment
    int lvl = 1;
    int remaining = exp;
    int threshold = 100;
    while (remaining >= threshold) {
      remaining -= threshold;
      lvl += 1;
      threshold += 50; // harder each level
    }
    return lvl;
  }

  int get expIntoLevel {
    int remaining = exp;
    int threshold = 100;
    while (remaining >= threshold) {
      remaining -= threshold;
      threshold += 50;
    }
    return remaining;
  }

  int get expForCurrentLevelCap {
    int remaining = exp;
    int threshold = 100;
    while (remaining >= threshold) {
      remaining -= threshold;
      threshold += 50;
    }
    return threshold;
  }
}
