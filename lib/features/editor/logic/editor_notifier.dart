import 'package:flutter/material.dart';
import '../../../core/models/segment.dart';
import '../../../core/services/ffmpeg_service.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class EditorNotifier extends ChangeNotifier {
  final FFmpegService ffmpeg;
  List<Segment> segments = [];
  int selectedIndex = 0;

  // export state
  bool exporting = false;
  double progress = 0.0;
  String? lastOut;

  EditorNotifier(FFmpegService fFmpegService, {FFmpegService? ffmpegService}) : ffmpeg = ffmpegService ?? FFmpegService();

  void setInitial(Duration total) {
    segments = [Segment(Duration.zero, total)];
    selectedIndex = 0;
    notifyListeners();
  }

  void selectIndex(int i) {
    if (i < 0 || i >= segments.length) return;
    selectedIndex = i;
    notifyListeners();
  }

  void splitAt(Duration playhead) {
    final i = segments.indexWhere((s) => s.contains(playhead));
    if (i < 0) return;
    final seg = segments[i];
    if ((playhead - seg.start).inMilliseconds < 120 || (seg.end - playhead).inMilliseconds < 120) return;
    final left = Segment(seg.start, playhead);
    final right = Segment(playhead, seg.end);
    segments[i] = left;
    segments.insert(i + 1, right);
    selectedIndex = i + 1;
    notifyListeners();
  }

  void deleteSelected() {
    if (segments.length == 1) return;
    segments.removeAt(selectedIndex);
    if (selectedIndex >= segments.length) selectedIndex = segments.length - 1;
    notifyListeners();
  }

  List<Segment> keptSegments() => List.unmodifiable(segments);

  /// Export orchestration. Returns output path on success or null.
  Future<String?> export(File srcFile, {required Future<String> Function(bool multi) suggestOut}) async {
    if (exporting) return null;
    exporting = true;
    progress = 0.0;
    lastOut = null;
    notifyListeners();

    final multi = segments.length > 1;
    final out = await suggestOut(multi);
    bool ok = false;

    try {
      if (!multi) {
        final seg = segments[0];
        ok = await ffmpeg.exportSingle(
          srcPath: srcFile.path,
          start: seg.start,
          dur: seg.end - seg.start,
          outPath: out,
          onProgress: (p) {
            progress = p;
            notifyListeners();
          },
        );
      } else {
        final segMaps = segments
            .map((s) => {'start': s.start, 'dur': Duration(milliseconds: s.lengthMs)})
            .toList();
        ok = await ffmpeg.exportConcat(
          srcPath: srcFile.path,
          segments: segMaps,
          outPath: out,
          onProgress: (p) {
            progress = p;
            notifyListeners();
          },
        );
      }
    } catch (e) {
      ok = false;
    }

    exporting = false;
    if (ok) {
      lastOut = out;
      notifyListeners();
      return out;
    } else {
      lastOut = null;
      notifyListeners();
      return null;
    }
  }
}
