import 'package:flutter/foundation.dart';

@immutable
class Segment {
  final Duration start;
  final Duration end;

  const Segment(this.start, this.end);

  int get lengthMs => end.inMilliseconds - start.inMilliseconds;

  bool contains(Duration t, {int tolMs = 60}) {
    final x = t.inMilliseconds;
    return x > start.inMilliseconds - tolMs && x < end.inMilliseconds + tolMs;
  }

  Segment copyWith({Duration? start, Duration? end}) {
    return Segment(start ?? this.start, end ?? this.end);
  }
}
