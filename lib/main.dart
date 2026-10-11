import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stridequest/app.dart';

void main() {
  // Disable runtime font fetching to respect offline-first principle
  GoogleFonts.config.allowRuntimeFetching = false;
  // Ensure proper orientation for step counting app
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const StrideQuestApp());
}