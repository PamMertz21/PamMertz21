import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/classifier.dart';
import '../services/firebase_service.dart';

const List<String> labels = [
  'Ketchup',
  'Mayonnaise',
  'Mustard',
  'Soy Sauce',
  'Vinegar',
  'Hot Sauce',
  'Salt',
  'Pepper',
  'Fish Sauce',
  'Garlic Sauce',
];

class ClassifierHome extends StatefulWidget {
  const ClassifierHome({Key? key}) : super(key: key);

  @override
  State<ClassifierHome> createState() => _ClassifierHomeState();
}

enum _InputSource { camera, gallery }

class _ClassifierHomeState extends State<ClassifierHome> {
  Uint8List? _imageBytes;
  String _resultText = '';
  CondimentClassifier? _classifier;
  bool _busy = false;
  _InputSource? _latestSource;
  List<double>? _lastScores;
  int? _lastTopIndex;
  bool _showBreakdown = false;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    setState(() => _busy = true);
    try {
      _classifier = await CondimentClassifier.create(
        'asset/model_unquant.tflite',
        normalizeToMinusOneToOne: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Model load error: $e')),
        );
      }
    }
    setState(() => _busy = false);
  }

  Future<void> _pickImageFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _resultText = '';
      _latestSource = _InputSource.camera;
    });
    await _runClassification(bytes);
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _resultText = '';
      _latestSource = _InputSource.gallery;
    });
    await _runClassification(bytes);
  }

  Future<void> _runClassification(Uint8List bytes) async {
    if (_classifier == null) return;
    setState(() => _busy = true);
    try {
      final res = await _classifier!.predict(bytes);
      final idx = res['index'] as int;
      final score = res['score'] as double;
      final scoresRaw = res['scores'] as List<dynamic>?;
      final scores = scoresRaw?.map((e) => (e as num).toDouble()).toList();
      final condiment = labels[idx];
      
      setState(() {
        _resultText = '$condiment (${(score * 100).toStringAsFixed(1)}%)';
        _lastScores = scores;
        _lastTopIndex = idx;
        _showBreakdown = false;
      });

      // Save to Firebase
      if (_latestSource != null) {
        await _firebaseService.saveScanResult(
          condiment: condiment,
          confidence: score,
          source: _latestSource == _InputSource.camera ? 'camera' : 'gallery',
          imageBytes: bytes,
        );
      }
    } catch (e) {
      setState(() {
        _resultText = 'Error: $e';
      });
    }
    setState(() => _busy = false);
  }

  @override
  void dispose() {
    _classifier?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFFDF3EC),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(170),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF8C42), Color(0xFFFF5F6D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scanner',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TabBar(
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        labelColor: Color(0xFFFF6B35),
                        unselectedLabelColor: Colors.white,
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelStyle: TextStyle(fontWeight: FontWeight.w600),
                        tabs: [
                          Tab(icon: Icon(Icons.camera_alt_rounded), text: 'Camera'),
                          Tab(icon: Icon(Icons.photo_library_rounded), text: 'Gallery'),
                          Tab(icon: Icon(Icons.insights_rounded), text: 'Analytics'),
                          Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Logs'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildCameraTab(theme),
            _buildGalleryTab(),
            const _AnalyticsTab(),
            const _LogsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraTab(ThemeData theme) {
    final hasCameraImage = _latestSource == _InputSource.camera && _imageBytes != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        children: [
          Expanded(
            child: _buildImagePreview(
              showImage: hasCameraImage,
              emptyMessage: 'Capture an image to begin',
            ),
          ),
          const SizedBox(height: 20),
          if (hasCameraImage && _resultText.isNotEmpty) _buildResultCard(theme),
          if (hasCameraImage && _resultText.isNotEmpty) const SizedBox(height: 20),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildGalleryTab() {
    final hasGalleryImage = _latestSource == _InputSource.gallery && _imageBytes != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        children: [
          Expanded(
            child: _buildImagePreview(
              showImage: hasGalleryImage,
              emptyMessage: 'Upload an image from your library to analyze it here.',
            ),
          ),
          const SizedBox(height: 20),
          if (hasGalleryImage && _resultText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _buildResultCard(Theme.of(context)),
            ),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFFF6B35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                side: const BorderSide(color: Color(0xFFFF6B35)),
              ),
              onPressed: _busy ? null : _pickImageFromGallery,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Upload from gallery'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview({required bool showImage, required String emptyMessage}) {
    final placeholder = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_outlined, size: 56, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text(
          emptyMessage,
          style: TextStyle(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: !showImage || _imageBytes == null
              ? Center(key: const ValueKey('placeholder'), child: placeholder)
              : Image.memory(
                  _imageBytes!,
                  key: const ValueKey('preview'),
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
        ),
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme) {
    final hasScores = _lastScores != null && _lastScores!.isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!hasScores) return;
        setState(() {
          _showBreakdown = !_showBreakdown;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFFF8C42).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.deepOrange.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detected condiment',
                  style: theme.textTheme.labelLarge?.copyWith(color: Colors.grey[600]),
                ),
                if (hasScores)
                  Icon(
                    _showBreakdown ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[500],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _resultText,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: const Color(0xFFFF6B35),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (hasScores && _showBreakdown) ...[
              const SizedBox(height: 16),
              _buildPerClassBreakdown(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPerClassBreakdown(ThemeData theme) {
    final scores = _lastScores;
    if (scores == null || scores.isEmpty) return const SizedBox.shrink();

    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final highlightedIndex = _lastTopIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confidence by class',
          style: theme.textTheme.labelMedium?.copyWith(
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(labels.length, (i) {
          final value = i < scores.length ? scores[i] : 0.0;
          final percent = (value * 100).clamp(0.0, 100.0);
          final barFactor = maxScore <= 0 ? 0.0 : value / maxScore;
          final isTop = highlightedIndex == i;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontWeight: isTop ? FontWeight.w700 : FontWeight.w500,
                        color: isTop ? const Color(0xFFFF6B35) : Colors.grey[800],
                      ),
                    ),
                    Text(
                      '${percent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: isTop ? FontWeight.w600 : FontWeight.w400,
                        color: isTop ? const Color(0xFFFF6B35) : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 6,
                    color: Colors.grey[200],
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: barFactor.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isTop
                                ? const [Color(0xFFFF8C42), Color(0xFFFF6B35)]
                                : [Colors.grey.shade400, Colors.grey.shade500],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: _RoundedActionButton(
        icon: Icons.camera_alt_rounded,
        label: 'Capture image',
        busy: _busy,
        onTap: () => _pickImageFromCamera(),
      ),
    );
  }
}

class _RoundedActionButton extends StatelessWidget {
  const _RoundedActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.busy,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
      onPressed: busy ? null : onTap,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(label),
              ],
            ),
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.deepOrange.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confidence trend',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const _ConfidenceTrendChart(),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.deepOrange.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scans by condiment',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              const _CondimentScanChart(),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.deepOrange.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confidence tiers',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              const _ConfidenceTierBars(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfidenceTrendChart extends StatefulWidget {
  const _ConfidenceTrendChart();

  @override
  State<_ConfidenceTrendChart> createState() => _ConfidenceTrendChartState();
}

class _ConfidenceTrendChartState extends State<_ConfidenceTrendChart> {
  final FirebaseService _firebaseService = FirebaseService();
  List<ConfidenceTrendPoint> _trendData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrendData();
  }

  Future<void> _loadTrendData() async {
    setState(() => _isLoading = true);
    final data = await _firebaseService.getConfidenceTrend();
    if (mounted) {
      setState(() {
        _trendData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF6B35).withOpacity(0.15),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_trendData.isEmpty) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF6B35).withOpacity(0.15),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: Text(
            'No data yet\nStart scanning to see trends',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final spots = _trendData.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.averageConfidence * 100, // Convert to percentage
      );
    }).toList();

    final maxY = _trendData.isEmpty
        ? 100.0
        : (_trendData.map((p) => p.averageConfidence * 100).reduce((a, b) => a > b ? a : b) * 1.1).clamp(0.0, 100.0).toDouble();
    final minY = 0.0;

    return Container(
      height: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35).withOpacity(0.15),
            Colors.white,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < _trendData.length) {
                    final date = _trendData[value.toInt()].date;
                    final dayName = _getDayName(date.weekday);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        dayName,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 20,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          minX: 0,
          maxX: (_trendData.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFFFF6B35),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFFFF6B35).withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}

class _CondimentScanChart extends StatefulWidget {
  const _CondimentScanChart();

  @override
  State<_CondimentScanChart> createState() => _CondimentScanChartState();
}

class _CondimentScanChartState extends State<_CondimentScanChart> {
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, int> _scanCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScanCounts();
  }

  Future<void> _loadScanCounts() async {
    setState(() => _isLoading = true);
    final counts = await _firebaseService.getCondimentScanCounts();
    if (mounted) {
      setState(() {
        _scanCounts = counts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_scanCounts.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No scans yet\nStart scanning to see data',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    // Sort by count (descending) and get top 10
    final sortedEntries = _scanCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCondiments = sortedEntries.take(10).toList();

    if (topCondiments.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No data available',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    final maxCount = topCondiments.first.value.toDouble();

    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxCount * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => const Color(0xFFFF6B35),
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final condiment = topCondiments[groupIndex].key;
                final count = topCondiments[groupIndex].value;
                return BarTooltipItem(
                  '$condiment\n$count ${count == 1 ? 'scan' : 'scans'}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < topCondiments.length) {
                    final condiment = topCondiments[index].key;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Transform.rotate(
                        angle: -0.5, // Rotate -45 degrees (in radians)
                        alignment: Alignment.center,
                        child: Text(
                          condiment,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: maxCount > 10 ? (maxCount / 5).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() == value) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxCount > 10 ? (maxCount / 5).ceilToDouble() : 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          barGroups: topCondiments.asMap().entries.map((entry) {
            final index = entry.key;
            final count = entry.value.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: count.toDouble(),
                  color: _getColorForIndex(index),
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _getColorForIndex(int index) {
    final colors = [
      const Color(0xFFFF6B35),
      const Color(0xFFFF8C42),
      const Color(0xFFFFA07A),
      const Color(0xFFFFB347),
      const Color(0xFFFFC857),
      const Color(0xFFFFD700),
      const Color(0xFFFFE135),
      const Color(0xFFFFE87C),
      const Color(0xFFFFF0A5),
      const Color(0xFFFFF8DC),
    ];
    return colors[index % colors.length];
  }

}

class _ConfidenceTierBars extends StatefulWidget {
  const _ConfidenceTierBars();

  @override
  State<_ConfidenceTierBars> createState() => _ConfidenceTierBarsState();
}

class _ConfidenceTierBarsState extends State<_ConfidenceTierBars> {
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, int> _tiers = {'high': 0, 'medium': 0, 'low': 0};

  @override
  void initState() {
    super.initState();
    _loadTiers();
  }

  Future<void> _loadTiers() async {
    final tiers = await _firebaseService.getConfidenceTiers();
    if (mounted) {
      setState(() {
        _tiers = tiers;
      });
    }
  }

  void _showTierScans(BuildContext context, String tierLabel, double minConfidence, double maxConfidence) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TierScansBottomSheet(
        tierLabel: tierLabel,
        minConfidence: minConfidence,
        maxConfidence: maxConfidence,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tiers = [
      _TierData(label: 'High > 80%', value: _tiers['high'] ?? 0, color: const Color(0xFF2ECC71)),
      _TierData(label: 'Medium 60-80%', value: _tiers['medium'] ?? 0, color: const Color(0xFFFFC857)),
      _TierData(label: 'Low < 60%', value: _tiers['low'] ?? 0, color: const Color(0xFFE74C3C)),
    ];

    final maxValue = tiers.fold<double>(0, (prev, tier) => tier.value > prev ? tier.value.toDouble() : prev);

    return Column(
      children: tiers.asMap().entries.map((entry) {
        final index = entry.key;
        final tier = entry.value;
        final percent = maxValue == 0 ? 0.0 : tier.value / maxValue;
        
        // Determine confidence range based on tier
        double minConfidence, maxConfidence;
        if (index == 0) {
          // High > 80%
          minConfidence = 0.8;
          maxConfidence = 1.0;
        } else if (index == 1) {
          // Medium 60-80%
          minConfidence = 0.6;
          maxConfidence = 0.8;
        } else {
          // Low < 60%
          minConfidence = 0.0;
          maxConfidence = 0.6;
        }
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: tier.value > 0
                ? () => _showTierScans(context, tier.label, minConfidence, maxConfidence)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(tier.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (tier.value > 0) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.touch_app, size: 16, color: Colors.grey[600]),
                        ],
                      ],
                    ),
                    Text('${tier.value} scans', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[200],
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: percent.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              tier.color.withOpacity(0.9),
                              tier.color,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TierData {
  const _TierData({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;
}

class _TierScansBottomSheet extends StatelessWidget {
  const _TierScansBottomSheet({
    required this.tierLabel,
    required this.minConfidence,
    required this.maxConfidence,
  });

  final String tierLabel;
  final double minConfidence;
  final double maxConfidence;

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tierLabel,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(minConfidence * 100).toStringAsFixed(0)}% - ${(maxConfidence * 100).toStringAsFixed(0)}% confidence',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<ScanResult>>(
                  stream: firebaseService.getScanResultsByConfidenceRange(
                    minConfidence: minConfidence,
                    maxConfidence: maxConfidence,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('Error loading scans: ${snapshot.error}'),
                          ],
                        ),
                      );
                    }

                    final scans = snapshot.data ?? [];

                    if (scans.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text(
                              'No scans in this range',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Scans will appear here as you use the app',
                              style: TextStyle(color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: scans.length,
                      itemBuilder: (context, index) {
                        final scan = scans[index];
                        final icon = scan.source == 'camera' ? Icons.camera_alt : Icons.photo_library;
                        final timeAgo = _formatTimeAgo(scan.timestamp);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepOrange.withOpacity(0.06),
                                blurRadius: 20,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 50,
                                width: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B35).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(icon, color: const Color(0xFFFF6B35)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      scan.condiment,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(scan.confidence * 100).toStringAsFixed(1)}% confidence • ${scan.source}',
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                timeAgo,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class _LogsTab extends StatelessWidget {
  const _LogsTab();

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    
    return StreamBuilder<List<ScanResult>>(
      stream: firebaseService.getScanResults(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('Error loading logs: ${snapshot.error}'),
              ],
            ),
          );
        }

        final logs = snapshot.data ?? [];

        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No scan history yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start scanning condiments to see your logs here',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final icon = log.source == 'camera' ? Icons.camera_alt : Icons.photo_library;
            final timeAgo = _formatTimeAgo(log.timestamp);
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepOrange.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: const Color(0xFFFF6B35)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.condiment, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          '${(log.confidence * 100).toStringAsFixed(1)}% confidence • ${log.source}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text(timeAgo, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
