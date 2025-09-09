import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../editor/ui/editor_page.dart';
import 'package:provider/provider.dart';
import '../../core/services/ffmpeg_service.dart';
import '../editor/logic/editor_notifier.dart';

class PickerPage extends StatefulWidget {
  const PickerPage({super.key});
  @override
  State<PickerPage> createState() => _PickerPageState();
}

class _PickerPageState extends State<PickerPage> {
  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.video);
    if (r == null || r.files.isEmpty) return;
    final path = r.files.single.path;
    if (path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot get path.')));
      return;
    }
    if (!mounted) return;
    // Provide EditorNotifier with FFmpegService (singleton style)
    final ff = FFmpegService();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => EditorNotifier(ffmpegService: ff),
        child: EditorPage(file: File(path)),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cut Editor')),
      body: Center(
        child: FilledButton.icon(onPressed: _pick, icon: const Icon(Icons.video_file_outlined), label: const Text('Pick Video')),
      ),
    );
  }
}
