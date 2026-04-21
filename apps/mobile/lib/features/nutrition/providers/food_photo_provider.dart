import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';

import '../../../core/api/api_client.dart';
import '../models/food_analysis.dart';

final _log = Logger();
final _picker = ImagePicker();

// ── State ────────────────────────────────────────────────────────────────────

class FoodPhotoState {
  const FoodPhotoState({
    this.imagePath,
    this.detectedFoods = const [],
    this.isAnalyzing = false,
    this.isLogging = false,
    this.error,
    this.notes,
    this.selectedMealType = 'lunch',
    this.loggedCount = 0,
  });

  final String? imagePath;
  final List<DetectedFoodItem> detectedFoods;
  final bool isAnalyzing;
  final bool isLogging;
  final String? error;
  final String? notes;
  final String selectedMealType;
  final int loggedCount; // >0 means logging finished successfully

  bool get hasImage => imagePath != null;
  bool get hasResults => detectedFoods.isNotEmpty;
  int get selectedCount => detectedFoods.where((f) => f.isSelected).length;

  double get totalSelectedCalories => detectedFoods
      .where((f) => f.isSelected)
      .fold(0.0, (sum, f) => sum + f.calories);

  FoodPhotoState copyWith({
    String? imagePath,
    List<DetectedFoodItem>? detectedFoods,
    bool? isAnalyzing,
    bool? isLogging,
    String? error,
    String? notes,
    String? selectedMealType,
    int? loggedCount,
  }) =>
      FoodPhotoState(
        imagePath: imagePath ?? this.imagePath,
        detectedFoods: detectedFoods ?? this.detectedFoods,
        isAnalyzing: isAnalyzing ?? this.isAnalyzing,
        isLogging: isLogging ?? this.isLogging,
        error: error,
        notes: notes ?? this.notes,
        selectedMealType: selectedMealType ?? this.selectedMealType,
        loggedCount: loggedCount ?? this.loggedCount,
      );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class FoodPhotoNotifier extends Notifier<FoodPhotoState> {
  @override
  FoodPhotoState build() => const FoodPhotoState();

  Future<void> pickAndAnalyze(ImageSource source) async {
    state = const FoodPhotoState(isAnalyzing: true);

    XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
        maxHeight: 1280,
      );
    } catch (e) {
      state = FoodPhotoState(error: 'Could not access camera/gallery: $e');
      return;
    }

    if (file == null) {
      // User cancelled — reset without error.
      state = const FoodPhotoState();
      return;
    }

    state = FoodPhotoState(imagePath: file.path, isAnalyzing: true);

    try {
      final bytes = await File(file.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = _mimeTypeFromPath(file.path);

      final res = await ref.read(apiClientProvider).dio.post(
        '/ai/analyze-food-photo',
        data: {'imageBase64': base64Image, 'mimeType': mimeType},
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );

      final analysis = FoodPhotoAnalysis.fromJson(
          res.data['data'] as Map<String, dynamic>);

      state = FoodPhotoState(
        imagePath: file.path,
        detectedFoods: analysis.detectedFoods,
        notes: analysis.notes,
        selectedMealType: _guessMealType(),
      );
    } on DioException catch (e, st) {
      _log.e('Food photo analysis failed', error: e, stackTrace: st);
      final msg = e.response?.data?['error']?['message'] as String?;
      state = FoodPhotoState(
        imagePath: file.path,
        error: msg ?? 'Analysis failed. Please try again.',
      );
    } catch (e, st) {
      _log.e('Food photo analysis failed', error: e, stackTrace: st);
      state = FoodPhotoState(
        imagePath: file.path,
        error: 'No food detected. Please try a clearer photo.',
      );
    }
  }

  void toggleItem(int index) {
    final foods = List<DetectedFoodItem>.from(state.detectedFoods);
    foods[index].isSelected = !foods[index].isSelected;
    state = state.copyWith(detectedFoods: foods);
  }

  void updateServing(int index, double newServingG) {
    final foods = List<DetectedFoodItem>.from(state.detectedFoods);
    foods[index].updateServing(newServingG);
    state = state.copyWith(detectedFoods: foods);
  }

  void removeItem(int index) {
    final foods = List<DetectedFoodItem>.from(state.detectedFoods)
      ..removeAt(index);
    state = state.copyWith(detectedFoods: foods);
  }

  void setMealType(String mealType) {
    state = state.copyWith(selectedMealType: mealType);
  }

  Future<void> logSelected() async {
    final selected = state.detectedFoods.where((f) => f.isSelected).toList();
    if (selected.isEmpty) return;

    state = state.copyWith(isLogging: true, error: null);

    try {
      final dio = ref.read(apiClientProvider).dio;
      final futures = selected.map((food) {
        final foodId = food.foodName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
        return dio.post('/nutrition/food-logs', data: {
          'foodId': 'photo_$foodId',
          'foodName': food.foodName,
          'mealType': state.selectedMealType,
          'servingG': food.servingG,
          'calories': food.calories,
          'proteinG': food.proteinG,
          'carbsG': food.carbsG,
          'fatG': food.fatG,
          if (food.fiberG != null) 'fiberG': food.fiberG,
        });
      });
      await Future.wait(futures);
      state = state.copyWith(isLogging: false, loggedCount: selected.length);
    } on DioException catch (e, st) {
      _log.e('Failed to log food items', error: e, stackTrace: st);
      state = state.copyWith(
        isLogging: false,
        error: 'Failed to save food logs. Please try again.',
      );
    }
  }

  void reset() => state = const FoodPhotoState();

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _mimeTypeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }

  String _guessMealType() {
    final hour = DateTime.now().hour;
    if (hour < 10) return 'breakfast';
    if (hour < 14) return 'lunch';
    if (hour < 18) return 'snack';
    return 'dinner';
  }
}

final foodPhotoProvider =
    NotifierProvider<FoodPhotoNotifier, FoodPhotoState>(FoodPhotoNotifier.new);
