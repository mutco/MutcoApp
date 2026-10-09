import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/mutco_app.dart';
import 'data/local_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MutcoApp(repository: LocalRepository(prefs), prefs: prefs));
}
