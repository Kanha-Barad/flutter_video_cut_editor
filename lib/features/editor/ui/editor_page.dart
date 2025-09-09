import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_editor/video_editor.dart';
import '../../../core/models/segment.dart';
import '../../picker/picker_page.dart';
import '../../editor/logic/editor_notifier.dart';
import 'widgets/timeline.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class EditorPage extends StatefulWidget {
  final File file;
  const EditorPage({super.key, required this.file});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final VideoPlayerController _vp;
  late final VideoEditorController _ve;
  Duration _playhead = Duration.zero;
  int? _playSegIndex;
  bool _ready = false;

  EditorNotifier get notifier => Provider.of<EditorNotifier>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _vp = VideoPlayerController.file(widget.file);
    _ve = VideoEditorController.file(widget.file, minDuration: Duration.zero, maxDuration: const Duration(hours: 6));
    _init();
  }

  Future<void> _init() async {
    await Future.wait([_vp.initialize(), _ve.initialize()]);
    await _vp.pause();
    _vp.setLooping(false);

    _vp.addListener(() async {
      if (!_vp.value.isInitialized) return;
      if (_vp.value.isPlaying) {
        setState(() => _playhead = _vp.value.position);
      }
      if (_playSegIndex != null && _vp.value.isPlaying) {
        final seg = notifier.segments[_playSegIndex!];
        if (_vp.value.position >= seg.end - const Duration(milliseconds: 50)) {
          await _jumpToNextSegmentOrStop();
        }
      }
    });

    notifier.setInitial(_vp.value.duration);

    // ensure trim timeline covers full
    _ve.updateTrim(_ve.minTrim, _ve.maxTrim);
    await Future.delayed(const Duration(milliseconds: 16));
    _ve.notifyListeners();

    setState(() {
      _ready = true;
    });
  }

  @override
  void dispose() {
    _vp.dispose();
    _ve.dispose();
    super.dispose();
  }

  Future<void> _seek(Duration t) async {
    _playhead = t;
    await _vp.seekTo(t);
    _playSegIndex = _findSegmentIndexFor(t);
    setState(() {});
  }

  int? _findSegmentIndexFor(Duration t) {
    final i = notifier.segments.indexWhere((s) => s.contains(t));
    return i >= 0 ? i : null;
  }

  int? _findNextSegmentIndexAfter(Duration t) {
    for (int i = 0; i < notifier.segments.length; i++) {
      if (notifier.segments[i].end > t) return i;
    }
    return null;
  }

  Future<void> _startPlaySegmentsMode() async {
    final idx = _findSegmentIndexFor(_playhead) ?? _findNextSegmentIndexAfter(_playhead);
    if (idx == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No segment to play')));
      return;
    }
    _playSegIndex = idx;
    final seg = notifier.segments[idx];
    final pos = _playhead;
    final target = (pos < seg.start || pos >= seg.end) ? seg.start : pos;
    await _vp.seekTo(target);
    await _vp.play();
    setState(() {});
  }

  Future<void> _jumpToNextSegmentOrStop() async {
    if (_playSegIndex == null) return;
    final next = _playSegIndex! + 1;
    if (next < notifier.segments.length) {
      _playSegIndex = next;
      await _vp.seekTo(notifier.segments[next].start);
    } else {
      _playSegIndex = null;
      await _vp.pause();
      await _vp.seekTo(notifier.segments.last.end);
    }
    setState(() {});
  }

  Future<String> _suggestOut(bool multi) async {
    final dir = await getApplicationDocumentsDirectory();
    final name = p.basenameWithoutExtension(widget.file.path);
    return p.join(dir.path, '${name}_${multi ? 'multi' : 'cut'}_${DateTime.now().millisecondsSinceEpoch}.mp4');
  }

  Future<void> _onExport() async {
    final out = await notifier.export(widget.file, suggestOut: (multi) => _suggestOut(multi));
    if (out != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: $out')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditorNotifier>(builder: (context, n, _) {
      return Scaffold(
        appBar: AppBar(
          title: Text(p.basename(widget.file.path)),
          actions: [
            IconButton(
              onPressed: !_ready
                  ? null
                  : () async {
                if (_vp.value.isPlaying) {
                  await _vp.pause();
                  setState(() {});
                } else {
                  await _startPlaySegmentsMode();
                }
              },
              icon: Icon(_vp.value.isPlaying ? Icons.pause : Icons.play_arrow),
            )
          ],
        ),
        body: !_ready
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(child: AspectRatio(aspectRatio: _vp.value.aspectRatio, child: VideoPlayer(_vp))),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, MediaQuery.of(context).padding.bottom + 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EditorTimeline(
                        veController: _ve,
                        playhead: _playhead,
                        segments: n.segments,
                        selected: n.selectedIndex,
                        onSeek: (t) => _seek(t),
                        onSelect: (i) {
                          n.selectIndex(i);
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        FilledButton.icon(onPressed: () {
                          notifier.splitAt(_playhead);
                          setState(() {});
                        }, icon: const Icon(Icons.content_cut), label: const Text('Split ✂️')),
                        OutlinedButton.icon(onPressed: () {
                          notifier.deleteSelected();
                          // ensure playhead inside selected
                          final seg = notifier.segments[notifier.selectedIndex];
                          if (_playhead < seg.start || _playhead > seg.end) _seek(seg.start);
                          setState(() {});
                        }, icon: const Icon(Icons.delete_forever), label: const Text('Delete')),
                        FilledButton.icon(
                            onPressed: notifier.exporting ? null : _onExport,
                            icon: const Icon(Icons.save_alt),
                            label: Text(notifier.segments.length == 1 ? 'Export' : 'Export (concat)')),
                      ]),
                      const SizedBox(height: 8),
                      if (notifier.exporting) ...[
                        LinearProgressIndicator(value: notifier.progress == 0 ? null : notifier.progress),
                        const SizedBox(height: 6),
                        Text('${(notifier.progress * 100).clamp(0, 100).toStringAsFixed(0)}%'),
                      ],
                      if (notifier.lastOut != null) ...[
                        const SizedBox(height: 6),
                        Text('Saved: ${notifier.lastOut}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
