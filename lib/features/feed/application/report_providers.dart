import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/features/feed/data/report_service.dart';

/// Provides the Firestore-backed report write service.
final Provider<ReportService> reportServiceProvider =
    Provider<ReportService>((Ref ref) {
  return FirestoreReportService(FirebaseFirestore.instance);
});
