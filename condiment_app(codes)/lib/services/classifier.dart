import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;

class CondimentClassifier {
  late Interpreter _interpreter;
  late int inputHeight;
  late int inputWidth;
  late bool isQuantized;
  late TensorType _inputType;
  late TensorType _outputType;
  late int _outputLength;
  late bool _normalizeToMinusOneToOne;

  CondimentClassifier._();

  static Future<CondimentClassifier> create(String assetPath, {bool normalizeToMinusOneToOne = false}) async {
    final cls = CondimentClassifier._();
    final interpreter = await Interpreter.fromAsset(assetPath);
    cls._interpreter = interpreter;
    cls._normalizeToMinusOneToOne = normalizeToMinusOneToOne;

    final inputTensor = interpreter.getInputTensor(0);
    final inputShape = inputTensor.shape; // e.g. [1,224,224,3]
    cls.inputHeight = inputShape.length >= 4 ? inputShape[1] : 224;
    cls.inputWidth = inputShape.length >= 4 ? inputShape[2] : 224;
    cls._inputType = inputTensor.type;
    cls.isQuantized = cls._inputType == TensorType.uint8;

    final outputTensor = interpreter.getOutputTensor(0);
    cls._outputType = outputTensor.type;
    final outShape = outputTensor.shape; // e.g. [1,10]
    cls._outputLength = outShape.length >= 2 ? outShape.sublist(1).reduce((a, b) => a * b) : outShape[0];

    print('Model loaded: inputShape=$inputShape inputType=${cls._inputType} outputShape=${outputTensor.shape} outputType=${cls._outputType}');
    return cls;
  }

  void close() {
    _interpreter.close();
  }

  /// Predict from raw image bytes (jpeg/png). Returns map with index, score, scores list.
  Future<Map<String, dynamic>> predict(Uint8List imageBytes) async {
    final preprocessed = _preprocess(imageBytes);

    // Build input tensor as nested List: [1][H][W][3]
    final input = List.generate(1, (_) => List.generate(inputHeight, (_) => List.generate(inputWidth, (_) => List.filled(3, 0.0))));
    for (int y = 0; y < inputHeight; y++) {
      for (int x = 0; x < inputWidth; x++) {
        final pixel = preprocessed.getPixel(x, y);
        final r = img.getRed(pixel);
        final g = img.getGreen(pixel);
        final b = img.getBlue(pixel);
        if (isQuantized) {
          // model expects uint8, provide raw 0-255 values
          input[0][y][x][0] = r.toDouble();
          input[0][y][x][1] = g.toDouble();
          input[0][y][x][2] = b.toDouble();
        } else {
          if (_normalizeToMinusOneToOne) {
            input[0][y][x][0] = (r / 127.5) - 1.0;
            input[0][y][x][1] = (g / 127.5) - 1.0;
            input[0][y][x][2] = (b / 127.5) - 1.0;
          } else {
            // normalize to 0..1
          input[0][y][x][0] = r / 255.0;
          input[0][y][x][1] = g / 255.0;
          input[0][y][x][2] = b / 255.0;
          }
        }
      }
    }

    // Prepare output buffer
    final output = List.generate(1, (_) => List.filled(_outputLength, 0.0));

    // Run inference
    _interpreter.run(input, output);

    List<double> results = output[0].map((e) => e.toDouble()).toList();

    // DEBUG: Print raw output
    print('DEBUG - Raw output: $results');
    
    // Check if output is already probabilities (0-1 range) or logits
    final maxVal = results.reduce((a, b) => a > b ? a : b);
    final minVal = results.reduce((a, b) => a < b ? a : b);
    print('DEBUG - Min: $minVal, Max: $maxVal');
    
    // If max value is very close to 1 and min is close to 0, it's already probabilities
    // Otherwise apply softmax
    List<double> probs;
    if (maxVal > 0.9 && minVal >= 0.0) {
      // Already probabilities, don't apply softmax
      probs = results;
      print('DEBUG - Output is already probabilities, skipping softmax');
    } else {
      // Apply softmax
      probs = _softmax(results);
      print('DEBUG - Applied softmax');
    }
    print('DEBUG - After processing: $probs');

    int maxIndex = 0;
    double maxScore = probs[0];
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > maxScore) {
        maxScore = probs[i];
        maxIndex = i;
      }
    }

    return {'index': maxIndex, 'score': maxScore, 'scores': probs};
  }

  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  img.Image _preprocess(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Unable to decode image');
    }

    // Normalize EXIF orientation so camera + gallery behave identically.
    final oriented = img.bakeOrientation(decoded);

    // Center-crop to square to avoid aspect-ratio surprises.
    final size = math.min(oriented.width, oriented.height);
    final left = (oriented.width - size) ~/ 2;
    final top = (oriented.height - size) ~/ 2;
    final cropped = img.copyCrop(oriented, left, top, size, size);

    // Resize to model input dimensions using high-quality interpolation.
    final resized = img.copyResize(
      cropped,
      width: inputWidth,
      height: inputHeight,
      interpolation: img.Interpolation.cubic,
    );

    // Optional mild tone adjustment to reduce extreme lighting differences.
    final adjusted = img.adjustColor(
      resized,
      gamma: 1.05,
      contrast: 1.02,
    );

    return adjusted;
  }
}
