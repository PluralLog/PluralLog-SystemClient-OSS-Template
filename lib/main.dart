import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/database/local_database.dart';
import 'app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabase.instance.init();

  runApp(const ProviderScope(child: PluralLogSystemTemplate()));
}

class PluralLogSystemTemplate extends StatelessWidget {
  const PluralLogSystemTemplate({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PluralLog System Template',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const AppShell(),
      debugShowCheckedModeBanner: true, // If you want to remove the debug mark in the TR, change this to false
    );
  }
}
