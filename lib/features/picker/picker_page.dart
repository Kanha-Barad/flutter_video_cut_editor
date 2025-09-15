import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../editor/ui/editor_page.dart';
import 'package:provider/provider.dart';
import '../../core/services/ffmpeg_service.dart';
import '../editor/logic/editor_notifier.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PickerPage extends StatefulWidget {
  const PickerPage({super.key});
  @override
  State<PickerPage> createState() => _PickerPageState();
}

class _PickerPageState extends State<PickerPage> {
  File? _selectedFile;

  Future<void> _pick() async {
    File? file;
    try {
      if (Platform.isIOS) {
        final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);

        // Check if running on Simulator
        final iosInfo = await DeviceInfoPlugin().iosInfo;
        final isSimulator = iosInfo.isPhysicalDevice == false;

        if (picked != null) {
          file = File(picked.path);
        } else if (isSimulator) {
          // Simulator fallback: load sample video from assets
          final bytes = await rootBundle.load('assets/sample.mp4');
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/sample.mp4');
          await tempFile.writeAsBytes(bytes.buffer.asUint8List());
          file = tempFile;
        }
      } else {
        final r = await FilePicker.platform.pickFiles(type: FileType.video);
        if (r != null && r.files.single.path != null) {
          file = File(r.files.single.path!);
        }
      }
    } catch (e) {
      debugPrint("Error picking video: $e");
    }

    if (!mounted) return;

    if (file == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No video selected.')));
      return;
    }

    setState(() => _selectedFile = file);
  }

  void _openEditor() {
    if (_selectedFile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => EditorNotifier(FFmpegService()),
            child: EditorPage(file: _selectedFile!),
          ),
        ),
      );
    }
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.video_library_rounded,
                      size: 80, color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  const Text("Select a Video",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                  if (_selectedFile != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      "Selected: ${_selectedFile!.path.split('/').last}",
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _openEditor,
                      icon: const Icon(Icons.edit),
                      label: const Text("Open in Editor"),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
