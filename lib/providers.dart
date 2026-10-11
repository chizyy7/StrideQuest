import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/models.dart';

// Stub user provider - to be replaced with actual repository connection
final userProvider = Provider.autoDispose<UserDoc?>((ref) {
  // For now, return a fake user to allow the app to start
  // In later steps, this will be connected to the actual user repository
  return UserDoc()
    ..uuid = 'fake-uuid'
    ..onboardingComplete = false
    ..createdAt = DateTime.now()
    ..dailyGoal = 6000;
});
