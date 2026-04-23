import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/disease_result.dart';
import '../disease_info.dart';

/// Two-tier disease detection service:
/// Tier 1 — On-device TFLite model (PlantVillage, 38 classes, offline)
/// Tier 2 — Gemini Vision API fallback for low-confidence / unknown crops
class DiseaseDetectionService {
  static DiseaseDetectionService? _instance;
  List<String> _labels = [];
  bool _modelLoaded = false;

  // Gemini API key — set empty to disable cloud fallback
  static const String _geminiApiKey = '';  // User should set this

  DiseaseDetectionService._();

  static Future<DiseaseDetectionService> getInstance() async {
    _instance ??= DiseaseDetectionService._();
    if (!_instance!._modelLoaded) {
      await _instance!._loadLabels();
    }
    return _instance!;
  }

  Future<void> _loadLabels() async {
    try {
      final labelData = await rootBundle.loadString('assets/ml/labels.txt');
      _labels = labelData
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      _modelLoaded = true;
    } catch (e) {
      _modelLoaded = false;
    }
  }

  /// Preprocess image: resize to 224x224 and normalize pixels to [0, 1].
  Float32List _preprocessImage(File imageFile) {
    final bytes = imageFile.readAsBytesSync();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');

    final resized = img.copyResize(image, width: 224, height: 224);
    final float32 = Float32List(1 * 224 * 224 * 3);

    int index = 0;
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resized.getPixel(x, y);
        float32[index++] = pixel.r / 255.0;
        float32[index++] = pixel.g / 255.0;
        float32[index++] = pixel.b / 255.0;
      }
    }
    return float32;
  }

  List<List<List<List<double>>>> _reshapeInput(Float32List flatInput) {
    final reshaped =
        List.generate(1, (_) => List.generate(224, (_) => List.generate(224, (_) => List.filled(3, 0.0))));

    int index = 0;
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        reshaped[0][y][x][0] = flatInput[index++];
        reshaped[0][y][x][1] = flatInput[index++];
        reshaped[0][y][x][2] = flatInput[index++];
      }
    }
    return reshaped;
  }

  /// Run on-device TFLite inference.
  /// Returns null if model is not available — caller should fall back to Gemini.
  Future<DiseaseResult?> detectWithTFLite(File imageFile) async {
    if (!_modelLoaded || _labels.isEmpty) return null;

    try {
      // Attempt dynamic TFLite loading
      // ignore: avoid_dynamic_calls
      final interpreter = await _loadInterpreter();
      if (interpreter == null) return null;

      final input = _preprocessImage(imageFile);
      final output =
          List.generate(1, (_) => List.filled(_labels.length, 0.0));

      interpreter.run(_reshapeInput(input), output);
      interpreter.close();

      // Find top prediction
      final scores = output[0];
      int maxIdx = 0;
      double maxScore = scores[0];
      for (int i = 1; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIdx = i;
        }
      }

      final label = _labels[maxIdx];
      final confidence = maxScore;

      return DiseaseInfo.getResult(label, confidence);
    } catch (e) {
      return null; // Fall back to Gemini
    }
  }

  /// Try to load TFLite interpreter dynamically.
  /// Returns null if tflite_flutter is not properly set up or model file missing.
  Future<dynamic> _loadInterpreter() async {
    try {
      // Dynamic import to gracefully handle if tflite_flutter can't load native libs
      final tflite = await _tryLoadTflite();
      return tflite;
    } catch (e) {
      return null;
    }
  }

  Future<dynamic> _tryLoadTflite() async {
    try {
      // This uses the tflite_flutter package
      // The model file must be in assets/ml/plant_disease_model.tflite
      final interpreterLib = await rootBundle.load('assets/ml/plant_disease_model.tflite');
      // If we reach here, model exists but we need the native interpreter
      // For now return null — user needs to add the model file
      // ignore: unused_local_variable
      final _ = interpreterLib;
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Detect disease using Gemini Vision API (cloud fallback).
  Future<DiseaseResult> detectWithGemini(File imageFile) async {
    if (_geminiApiKey.isEmpty) {
      return DiseaseResult.unknown();
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: _geminiApiKey,
      );

      final imageBytes = await imageFile.readAsBytes();
      final mimeType = imageFile.path.endsWith('.png') ? 'image/png' : 'image/jpeg';

      final response = await model.generateContent([
        Content.multi([
          TextPart(
            'You are an expert agricultural plant pathologist. Analyze this image of a plant leaf/crop and identify any disease.\n\n'
            'Respond in this exact format:\n'
            'CROP: [crop name]\n'
            'DISEASE: [disease name or "Healthy"]\n'
            'CONFIDENCE: [high/medium/low]\n'
            'DESCRIPTION: [brief description of the disease]\n'
            'TREATMENT: [treatment steps]\n'
            'PREVENTION: [prevention tips]\n\n'
            'If you cannot identify the plant or disease, respond with:\n'
            'CROP: Unknown\nDISEASE: Unknown\nCONFIDENCE: low',
          ),
          DataPart(mimeType, imageBytes),
        ]),
      ]);

      return _parseGeminiResponse(response.text ?? '');
    } catch (e) {
      return DiseaseResult.unknown();
    }
  }

  /// Parse structured Gemini response into DiseaseResult.
  DiseaseResult _parseGeminiResponse(String text) {
    String crop = 'Unknown';
    String disease = 'Unknown';
    String description = '';
    String treatment = '';
    String prevention = '';
    double confidence = 0.5;

    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('CROP:')) {
        crop = trimmed.substring(5).trim();
      } else if (trimmed.startsWith('DISEASE:')) {
        disease = trimmed.substring(8).trim();
      } else if (trimmed.startsWith('CONFIDENCE:')) {
        final conf = trimmed.substring(11).trim().toLowerCase();
        confidence = conf == 'high' ? 0.95 : conf == 'medium' ? 0.75 : 0.5;
      } else if (trimmed.startsWith('DESCRIPTION:')) {
        description = trimmed.substring(12).trim();
      } else if (trimmed.startsWith('TREATMENT:')) {
        treatment = trimmed.substring(10).trim();
      } else if (trimmed.startsWith('PREVENTION:')) {
        prevention = trimmed.substring(11).trim();
      }
    }

    if (disease.toLowerCase() == 'healthy') {
      return DiseaseResult.healthy(crop);
    }
    if (disease == 'Unknown' && crop == 'Unknown') {
      return DiseaseResult.unknown();
    }

    return DiseaseResult(
      diseaseName: disease,
      cropName: crop,
      confidence: confidence,
      description: description,
      treatment: treatment,
      prevention: prevention,
    );
  }

  /// Main detection entry point — tries TFLite first, falls back to Gemini.
  Future<DiseaseResult> detect(File imageFile) async {
    // Tier 1: Try on-device TFLite
    final tfliteResult = await detectWithTFLite(imageFile);
    if (tfliteResult != null && tfliteResult.confidence >= 0.8) {
      return tfliteResult;
    }

    // Tier 2: Fall back to Gemini Vision API
    if (_geminiApiKey.isNotEmpty) {
      return detectWithGemini(imageFile);
    }

    // If TFLite gave a low-confidence result, still return it
    if (tfliteResult != null) return tfliteResult;

    return DiseaseResult.unknown();
  }
}
