import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'features/picker/picker_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cut Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: kIsWeb
          ? const Scaffold(
              body: Center(child: Text('Only Android/iOS supported')))
          : const PickerPage(),
    );
  }
}
