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

  EditorNotifier get notifier =>
      Provider.of<EditorNotifier>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _vp = VideoPlayerController.file(widget.file);
    _ve = VideoEditorController.file(widget.file,
        minDuration: Duration.zero, maxDuration: const Duration(hours: 6));
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
    final idx = _findSegmentIndexFor(_playhead) ??
        _findNextSegmentIndexAfter(_playhead);
    if (idx == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No segment to play')));
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
    Directory dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    if (!await dir.exists()) await dir.create(recursive: true);
    final name = p.basenameWithoutExtension(widget.file.path);
    return p.join(dir.path,
        '${name}_${multi ? 'multi' : 'cut'}_${DateTime.now().millisecondsSinceEpoch}.mp4');
  }

  Future<void> _onExport() async {
    final out = await notifier.export(widget.file,
        suggestOut: (multi) => _suggestOut(multi));
    if (out != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Saved: $out')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Export failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditorNotifier>(builder: (context, n, _) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            p.basename(widget.file.path),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
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
                    // Video player with overlay
                    Expanded(
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AspectRatio(
                                aspectRatio: _vp.value.aspectRatio,
                                child: VideoPlayer(_vp),
                              ),
                              if (!_vp.value.isPlaying)
                                Container(
                                  color: Colors.black26,
                                  child: const Icon(Icons.play_circle_fill,
                                      size: 64, color: Colors.white70),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom controls
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(12, 12, 12,
                            MediaQuery.of(context).padding.bottom + 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Timeline card
                            Card(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: EditorTimeline(
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
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                  onPressed: () {
                                    notifier.splitAt(_playhead);
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.content_cut,
                                      color: Colors.white),
                                  label: const Text(
                                    'Split',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: Colors.red, width: 2),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                  onPressed: () {
                                    notifier.deleteSelected();
                                    final seg = notifier
                                        .segments[notifier.selectedIndex];
                                    if (_playhead < seg.start ||
                                        _playhead > seg.end) _seek(seg.start);
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.delete_forever,
                                      color: Colors.red),
                                  label: const Text('Delete'),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Export button
                            Center(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14),
                                ),
                                onPressed:
                                    notifier.exporting ? null : _onExport,
                                icon: const Icon(Icons.save_alt,
                                    color: Colors.white),
                                label: Text(
                                  notifier.segments.length == 1
                                      ? 'Export Video'
                                      : 'Export & Merge',
                                  style: const TextStyle(
                                      fontSize: 16, color: Colors.white),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Export progress card
                            if (notifier.exporting) ...[
                              Card(
                                margin: const EdgeInsets.only(top: 12),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text("Exporting...",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                          value: notifier.progress == 0
                                              ? null
                                              : notifier.progress),
                                      const SizedBox(height: 6),
                                      Text(
                                          '${(notifier.progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                          style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            // Last export preview
                            if (notifier.lastOut != null) ...[
                              Card(
                                margin: const EdgeInsets.only(top: 12),
                                child: ListTile(
                                  leading: const Icon(Icons.video_library,
                                      color: Colors.teal),
                                  title: const Text("Exported Video"),
                                  subtitle: Text(
                                    notifier.lastOut!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.open_in_new),
                                    onPressed: () async {
                                      final file = File(notifier.lastOut!);
                                      if (await file.exists()) {
                                        // TODO: open in external player
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
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
