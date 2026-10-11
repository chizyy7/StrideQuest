// TODO: Implement settings controller with actual logic
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart';

final userProvider = Provider.autoDispose<UserDoc?>((ref) {
  // TODO: Connect to actual user repository
  return null;
});