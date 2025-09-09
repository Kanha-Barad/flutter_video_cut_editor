import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/statistics.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';

/// Simple service wrapper for export operations.
/// - onProgress: value from 0..1 (best-effort)
class FFmpegService {
  Future<bool> runCommand(
      String cmd, {
        required int totalMs,
        void Function(double progress)? onProgress,
      }) async {
    final completer = Completer<bool>();

    await FFmpegKit.executeAsync(
      cmd,
          (session) async {
        final rc = await session.getReturnCode();
        final ok = ReturnCode.isSuccess(rc);
        if (!ok) {
          final logs = (await session.getAllLogsAsString()) ?? '';
          // Optionally log
          debugPrint('FFmpeg failed rc=${rc?.getValue()} logs: $logs');
        } else {
          debugPrint('FFmpeg success rc=${rc?.getValue()}');
        }
        if (!completer.isCompleted) completer.complete(ok);
      },
          (log) {
        // optionally debugPrint(log.getMessage());
      },
          (Statistics st) {
        final t = st.getTime(); // ms processed
        if (t > 0 && totalMs > 0) {
          final p = (t / totalMs).clamp(0.0, 1.0);
          if (onProgress != null) onProgress(p);
        }
      },
    );

    return completer.future;
  }

  String _fmtMs(Duration d) {
    final ms = d.inMilliseconds;
    final s = (ms / 1000.0).toStringAsFixed(3);
    return s;
  }

  /// Single segment: try copy then fallback reencode.
  Future<bool> exportSingle({
    required String srcPath,
    required Duration start,
    required Duration dur,
    required String outPath,
    void Function(double progress)? onProgress,
  }) async {
    final startSec = _fmtMs(start);
    final durSec = _fmtMs(dur);
    final copyCmd =
        '-y -hide_banner -nostdin -ss $startSec -i "${srcPath}" -t $durSec -c copy -movflags +faststart "${outPath}"';

    final okCopy = await runCommand(copyCmd, totalMs: dur.inMilliseconds, onProgress: onProgress);
    if (okCopy) return true;

    final encCmd =
        '-y -hide_banner -nostdin -ss $startSec -i "${srcPath}" -t $durSec '
        '-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,fps=30,format=yuv420p" '
        '-c:v libx264 -preset veryfast -crf 23 '
        '-c:a aac -ar 48000 -ac 2 -b:a 128k -movflags +faststart "${outPath}"';

    final okEnc = await runCommand(encCmd, totalMs: dur.inMilliseconds, onProgress: onProgress);
    return okEnc;
  }

  /// Multi-segment: use filter_complex trim+concat (re-encode).
  Future<bool> exportConcat({
    required String srcPath,
    required List<Map<String, Duration>> segments, // [{'start': d, 'dur': d}, ...]
    required String outPath,
    void Function(double progress)? onProgress,
  }) async {
    final totalMs = segments.fold<int>(0, (a, b) => a + (b['dur']!.inMilliseconds));
    // Build filter_complex: [0:v]trim=start=X:end=Y,...; [0:a]atrim=...
    final parts = <String>[];
    for (int i = 0; i < segments.length; i++) {
      final s = segments[i];
      final start = (s['start']!.inMilliseconds / 1000.0).toStringAsFixed(3);
      final endSec = ((s['start']!.inMilliseconds + s['dur']!.inMilliseconds) / 1000.0).toStringAsFixed(3);
      parts.add('[0:v]trim=start=$start:end=$endSec,setpts=PTS-STARTPTS[v$i]');
      parts.add('[0:a]atrim=start=$start:end=$endSec,asetpts=PTS-STARTPTS[a$i]');
    }
    final vList = List.generate(segments.length, (i) => '[v$i]').join();
    final aList = List.generate(segments.length, (i) => '[a$i]').join();
    final n = segments.length;
    final filter = '${parts.join(';')};$vList$aList concat=n=$n:v=1:a=1[vtmp][atmp];'
        '[vtmp]fps=30,format=yuv420p,scale=trunc(iw/2)*2:trunc(ih/2)*2[vout];'
        '[atmp]anull[aout]';

    final cmd =
        '-y -hide_banner -nostdin -i "${srcPath}" -filter_complex "$filter" -map "[vout]" -map "[aout]" '
        '-c:v libx264 -preset veryfast -crf 23 -c:a aac -ar 48000 -ac 2 -b:a 128k -movflags +faststart "${outPath}"';

    final ok = await runCommand(cmd, totalMs: totalMs, onProgress: onProgress);
    return ok;
  }
}
