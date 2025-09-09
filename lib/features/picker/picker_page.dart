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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cannot get path.')));
      return;
    }
    if (!mounted) return;
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
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.video_library_rounded,
                      size: 80, color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  const Text(
                    "Select a Video",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Pick a video file from your device to start editing.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _pick,
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Pick Video"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
