import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Save a scan result to Firestore
  Future<void> saveScanResult({
    required String condiment,
    required double confidence,
    required String source, // 'camera' or 'gallery'
    Uint8List? imageBytes,
  }) async {
    try {
      final scanData = {
        'condiment': condiment,
        'confidence': confidence,
        'source': source,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
      };

      // Save to Firestore
      await _firestore.collection('scans').add(scanData);

      // Log analytics event
      await _analytics.logEvent(
        name: 'scan_completed',
        parameters: {
          'condiment': condiment,
          'confidence': (confidence * 100).round(),
          'source': source,
        },
      );
    } catch (e) {
      print('Error saving scan result: $e');
      // Don't throw - allow app to continue even if Firebase fails
    }
  }

  /// Get all scan results for logs
  Stream<List<ScanResult>> getScanResults() {
    return _firestore
        .collection('scans')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ScanResult(
          id: doc.id,
          condiment: data['condiment'] ?? 'Unknown',
          confidence: (data['confidence'] ?? 0.0).toDouble(),
          source: data['source'] ?? 'unknown',
          timestamp: data['timestamp']?.toDate() ?? 
                    (data['date'] != null ? DateTime.parse(data['date']) : DateTime.now()),
        );
      }).toList();
    });
  }

  /// Get scan results sorted by confidence (highest first)
  Stream<List<ScanResult>> getScanResultsByConfidence() {
    return _firestore
        .collection('scans')
        .orderBy('confidence', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ScanResult(
          id: doc.id,
          condiment: data['condiment'] ?? 'Unknown',
          confidence: (data['confidence'] ?? 0.0).toDouble(),
          source: data['source'] ?? 'unknown',
          timestamp: data['timestamp']?.toDate() ?? 
                    (data['date'] != null ? DateTime.parse(data['date']) : DateTime.now()),
        );
      }).toList();
    });
  }

  /// Get scan results sorted by condiment name (alphabetically)
  Stream<List<ScanResult>> getScanResultsByCondiment() {
    return _firestore
        .collection('scans')
        .orderBy('condiment', descending: false)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ScanResult(
          id: doc.id,
          condiment: data['condiment'] ?? 'Unknown',
          confidence: (data['confidence'] ?? 0.0).toDouble(),
          source: data['source'] ?? 'unknown',
          timestamp: data['timestamp']?.toDate() ?? 
                    (data['date'] != null ? DateTime.parse(data['date']) : DateTime.now()),
        );
      }).toList();
    });
  }

  /// Get scan results filtered by confidence range
  Stream<List<ScanResult>> getScanResultsByConfidenceRange({
    required double minConfidence,
    required double maxConfidence,
  }) {
    return _firestore
        .collection('scans')
        .orderBy('confidence', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            final confidence = (data['confidence'] ?? 0.0).toDouble();
            if (confidence >= minConfidence && confidence <= maxConfidence) {
              return ScanResult(
                id: doc.id,
                condiment: data['condiment'] ?? 'Unknown',
                confidence: confidence,
                source: data['source'] ?? 'unknown',
                timestamp: data['timestamp']?.toDate() ?? 
                          (data['date'] != null ? DateTime.parse(data['date']) : DateTime.now()),
              );
            }
            return null;
          })
          .where((result) => result != null)
          .cast<ScanResult>()
          .toList();
    });
  }

  /// Get analytics data for confidence tiers
  Future<Map<String, int>> getConfidenceTiers() async {
    try {
      final thirtyDaysAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 30))
      );
      
      final snapshot = await _firestore
          .collection('scans')
          .where('timestamp', isGreaterThan: thirtyDaysAgo)
          .orderBy('timestamp', descending: true)
          .get();

      int high = 0; // > 80%
      int medium = 0; // 60-80%
      int low = 0; // < 60%

      for (var doc in snapshot.docs) {
        final confidence = (doc.data()['confidence'] ?? 0.0).toDouble();
        if (confidence > 0.8) {
          high++;
        } else if (confidence >= 0.6) {
          medium++;
        } else {
          low++;
        }
      }

      return {
        'high': high,
        'medium': medium,
        'low': low,
      };
    } catch (e) {
      print('Error getting confidence tiers: $e');
      return {'high': 0, 'medium': 0, 'low': 0};
    }
  }

  /// Get total scan count
  Future<int> getTotalScans() async {
    try {
      final snapshot = await _firestore.collection('scans').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting total scans: $e');
      return 0;
    }
  }

  /// Get scan counts per condiment class
  Future<Map<String, int>> getCondimentScanCounts() async {
    try {
      final snapshot = await _firestore.collection('scans').get();
      
      final Map<String, int> counts = {};
      
      for (var doc in snapshot.docs) {
        final condiment = doc.data()['condiment'] ?? 'Unknown';
        counts[condiment] = (counts[condiment] ?? 0) + 1;
      }
      
      return counts;
    } catch (e) {
      print('Error getting condiment scan counts: $e');
      return {};
    }
  }

  /// Get confidence trend data for the last 7 days
  Future<List<ConfidenceTrendPoint>> getConfidenceTrend() async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo = Timestamp.fromDate(now.subtract(const Duration(days: 7)));
      
      final snapshot = await _firestore
          .collection('scans')
          .where('timestamp', isGreaterThan: sevenDaysAgo)
          .orderBy('timestamp', descending: false)
          .get();

      // Group scans by day
      final Map<String, List<double>> dailyConfidences = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp']?.toDate() ?? 
                         (data['date'] != null ? DateTime.parse(data['date']) : DateTime.now());
        final dayKey = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
        final confidence = (data['confidence'] ?? 0.0).toDouble();
        
        dailyConfidences.putIfAbsent(dayKey, () => []).add(confidence);
      }

      // Calculate average confidence per day for last 7 days
      final List<ConfidenceTrendPoint> trendPoints = [];
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final confidences = dailyConfidences[dayKey] ?? [];
        
        final avgConfidence = confidences.isEmpty 
            ? 0.0 
            : confidences.reduce((a, b) => a + b) / confidences.length;
        
        trendPoints.add(ConfidenceTrendPoint(
          date: date,
          averageConfidence: avgConfidence,
          count: confidences.length,
        ));
      }

      return trendPoints;
    } catch (e) {
      print('Error getting confidence trend: $e');
      return [];
    }
  }
}

class ConfidenceTrendPoint {
  final DateTime date;
  final double averageConfidence;
  final int count;

  ConfidenceTrendPoint({
    required this.date,
    required this.averageConfidence,
    required this.count,
  });
}

class ScanResult {
  final String id;
  final String condiment;
  final double confidence;
  final String source;
  final DateTime timestamp;

  ScanResult({
    required this.id,
    required this.condiment,
    required this.confidence,
    required this.source,
    required this.timestamp,
  });
}

