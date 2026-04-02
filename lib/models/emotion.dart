enum Emotion {
  happy,
  sad,
  anxious,
  stressed,
  neutral,
  angry,
}

extension EmotionExtension on Emotion {
  String get label {
    switch (this) {
      case Emotion.happy:    return 'Happy';
      case Emotion.sad:      return 'Sad';
      case Emotion.anxious:  return 'Anxious';
      case Emotion.stressed: return 'Stressed';
      case Emotion.neutral:  return 'Neutral';
      case Emotion.angry:    return 'Angry';
    }
  }
}
