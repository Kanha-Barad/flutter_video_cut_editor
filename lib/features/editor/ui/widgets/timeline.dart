import 'package:flutter/material.dart';
import 'package:video_editor/video_editor.dart';
import '../../../../core/models/segment.dart';

typedef SeekCallback = Future<void> Function(Duration pos);
typedef SelectCallback = void Function(int index);

class EditorTimeline extends StatelessWidget {
  final VideoEditorController veController;
  final Duration playhead;
  final List<Segment> segments;
  final int selected;
  final SeekCallback onSeek;
  final SelectCallback onSelect;

  const EditorTimeline({
    super.key,
    required this.veController,
    required this.playhead,
    required this.segments,
    required this.selected,
    required this.onSeek,
    required this.onSelect,
  });

  Duration _timeAtDx(double dx, double width, Duration total) {
    final ratio = (dx / width).clamp(0.0, 1.0);
    final ms = (total.inMilliseconds * ratio).round();
    return Duration(milliseconds: ms);
  }

  double _dxAtTime(Duration t, double width, Duration total) {
    final ratio = (t.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return ratio * width;
  }

  @override
  Widget build(BuildContext context) {
    const double h = 96;
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;
      final total = Duration(milliseconds: (veController.maxTrim * 1000).round()); // video duration (video_editor controller set earlier)
      final overlays = <Widget>[];

      for (int i = 0; i < segments.length; i++) {
        final s = segments[i];
        final left = _dxAtTime(s.start, width, total);
        final right = _dxAtTime(s.end, width, total);
        overlays.add(Positioned(
          left: left,
          top: 0,
          width: (right - left).clamp(2.0, width),
          height: h,
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected == i ? Colors.amber : Colors.indigo.withOpacity(0.5),
                  width: selected == i ? 3 : 2,
                ),
                color: (selected == i ? Colors.amber.withOpacity(0.10) : Colors.indigo.withOpacity(0.05)),
              ),
            ),
          ),
        ));
      }

      final headX = _dxAtTime(playhead, width, total);
      overlays.add(Positioned(left: headX - 1, top: 0, width: 2, height: h, child: Container(color: Colors.white)));

      return Stack(children: [
        SizedBox(
          height: h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TrimTimeline(controller: veController, quantity: 10, padding: EdgeInsets.zero),
          ),
        ),
        ...overlays,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final t = _timeAtDx(d.localPosition.dx, width, total);
              onSeek(t);
              final idx = segments.indexWhere((s) => s.contains(t));
              if (idx >= 0) onSelect(idx);
            },
            onPanUpdate: (d) {
              final t = _timeAtDx(d.localPosition.dx, width, total);
              onSeek(t);
            },
          ),
        ),
      ]);
    });
  }
}
