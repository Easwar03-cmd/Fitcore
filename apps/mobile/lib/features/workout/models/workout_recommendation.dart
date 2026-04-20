class SuggestedExercise {
  const SuggestedExercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.restSec,
  });

  final String name;
  final int sets;
  final String reps; // e.g. "8-12", "15-20", "30s"
  final int restSec;

  factory SuggestedExercise.fromJson(Map<String, dynamic> json) =>
      SuggestedExercise(
        name: json['name'] as String,
        sets: (json['sets'] as num).toInt(),
        reps: json['reps'].toString(),
        restSec: (json['restSec'] as num).toInt(),
      );
}

class WorkoutRecommendation {
  const WorkoutRecommendation({
    required this.workoutName,
    required this.reasoning,
    required this.targetMuscleGroups,
    required this.suggestedExercises,
    required this.estimatedDurationMin,
    required this.intensity,
  });

  final String workoutName;
  final String reasoning;
  final List<String> targetMuscleGroups;
  final List<SuggestedExercise> suggestedExercises;
  final int estimatedDurationMin;
  final String intensity; // 'light' | 'moderate' | 'hard'

  factory WorkoutRecommendation.fromJson(Map<String, dynamic> json) =>
      WorkoutRecommendation(
        workoutName: json['workoutName'] as String,
        reasoning: json['reasoning'] as String,
        targetMuscleGroups: List<String>.from(json['targetMuscleGroups'] as List),
        suggestedExercises: (json['suggestedExercises'] as List)
            .map((e) => SuggestedExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
        estimatedDurationMin: (json['estimatedDurationMin'] as num).toInt(),
        intensity: json['intensity'] as String,
      );
}
