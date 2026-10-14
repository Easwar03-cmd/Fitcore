import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';

enum MuscleGroup { chest, back, shoulders, arms, legs, core, cardio }

extension MuscleGroupX on MuscleGroup {
  String get label => switch (this) {
        MuscleGroup.chest => 'Chest',
        MuscleGroup.back => 'Back',
        MuscleGroup.shoulders => 'Shoulders',
        MuscleGroup.arms => 'Arms',
        MuscleGroup.legs => 'Legs',
        MuscleGroup.core => 'Core',
        MuscleGroup.cardio => 'Cardio',
      };

  IconData get icon => switch (this) {
        MuscleGroup.chest => PhosphorIconsRegular.barbell,
        MuscleGroup.back => PhosphorIconsRegular.personSimpleTaiChi,
        MuscleGroup.shoulders => PhosphorIconsRegular.arrowsOutCardinal,
        MuscleGroup.arms => PhosphorIconsRegular.handFist,
        MuscleGroup.legs => PhosphorIconsRegular.personSimpleRun,
        MuscleGroup.core => PhosphorIconsRegular.target,
        MuscleGroup.cardio => PhosphorIconsRegular.heartbeat,
      };

  Color get color => switch (this) {
        MuscleGroup.chest => AppColors.salmon,
        MuscleGroup.back => AppColors.sky,
        MuscleGroup.shoulders => AppColors.butter,
        MuscleGroup.arms => AppColors.lime,
        MuscleGroup.legs => AppColors.sky,
        MuscleGroup.core => AppColors.lime,
        MuscleGroup.cardio => AppColors.salmon,
      };
}

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.isBodyweight = false,
    this.timedOnly = false,
  });

  final String id;
  final String name;
  final MuscleGroup muscleGroup;

  /// True for bodyweight / calisthenics exercises — hides the weight input.
  final bool isBodyweight;

  /// True for exercises measured in duration (plank, wall sit) — shows a
  /// seconds field instead of a reps field.
  final bool timedOnly;
}

// 50 hardcoded exercises (6 chest, 7 back, 5 shoulders, 7 arms, 10 legs, 7 core, 8 cardio)
const kExerciseLibrary = <Exercise>[
  // ── Chest ────────────────────────────────────────────────────────────────
  Exercise(id: 'bench_press', name: 'Bench Press', muscleGroup: MuscleGroup.chest),
  Exercise(id: 'incline_bench', name: 'Incline Bench Press', muscleGroup: MuscleGroup.chest),
  Exercise(id: 'decline_bench', name: 'Decline Bench Press', muscleGroup: MuscleGroup.chest),
  Exercise(id: 'chest_fly', name: 'Chest Fly', muscleGroup: MuscleGroup.chest),
  Exercise(id: 'push_up', name: 'Push-Up', muscleGroup: MuscleGroup.chest),
  Exercise(id: 'cable_crossover', name: 'Cable Crossover', muscleGroup: MuscleGroup.chest),
  // ── Back ─────────────────────────────────────────────────────────────────
  Exercise(id: 'pull_up', name: 'Pull-Up', muscleGroup: MuscleGroup.back),
  Exercise(id: 'barbell_row', name: 'Barbell Row', muscleGroup: MuscleGroup.back),
  Exercise(id: 'seated_row', name: 'Seated Cable Row', muscleGroup: MuscleGroup.back),
  Exercise(id: 'lat_pulldown', name: 'Lat Pulldown', muscleGroup: MuscleGroup.back),
  Exercise(id: 'deadlift', name: 'Deadlift', muscleGroup: MuscleGroup.back),
  Exercise(id: 'db_row', name: 'Single-Arm Dumbbell Row', muscleGroup: MuscleGroup.back),
  Exercise(id: 'face_pull', name: 'Face Pull', muscleGroup: MuscleGroup.back),
  // ── Shoulders ────────────────────────────────────────────────────────────
  Exercise(id: 'overhead_press', name: 'Overhead Press', muscleGroup: MuscleGroup.shoulders),
  Exercise(id: 'lateral_raise', name: 'Lateral Raise', muscleGroup: MuscleGroup.shoulders),
  Exercise(id: 'front_raise', name: 'Front Raise', muscleGroup: MuscleGroup.shoulders),
  Exercise(id: 'rear_delt_fly', name: 'Rear Delt Fly', muscleGroup: MuscleGroup.shoulders),
  Exercise(id: 'arnold_press', name: 'Arnold Press', muscleGroup: MuscleGroup.shoulders),
  // ── Arms ─────────────────────────────────────────────────────────────────
  Exercise(id: 'bicep_curl', name: 'Bicep Curl', muscleGroup: MuscleGroup.arms),
  Exercise(id: 'hammer_curl', name: 'Hammer Curl', muscleGroup: MuscleGroup.arms),
  Exercise(id: 'concentration_curl', name: 'Concentration Curl', muscleGroup: MuscleGroup.arms),
  Exercise(id: 'tricep_pushdown', name: 'Tricep Pushdown', muscleGroup: MuscleGroup.arms),
  Exercise(id: 'skull_crusher', name: 'Skull Crusher', muscleGroup: MuscleGroup.arms),
  Exercise(id: 'overhead_tricep', name: 'Overhead Tricep Extension', muscleGroup: MuscleGroup.arms),
  Exercise(id: 'dips', name: 'Dips', muscleGroup: MuscleGroup.arms),
  // ── Legs ─────────────────────────────────────────────────────────────────
  Exercise(id: 'squat', name: 'Squat', muscleGroup: MuscleGroup.legs),
  Exercise(id: 'romanian_dl', name: 'Romanian Deadlift', muscleGroup: MuscleGroup.legs),
  Exercise(id: 'leg_press', name: 'Leg Press', muscleGroup: MuscleGroup.legs),
  Exercise(id: 'leg_curl', name: 'Leg Curl', muscleGroup: MuscleGroup.legs),
  Exercise(id: 'leg_extension', name: 'Leg Extension', muscleGroup: MuscleGroup.legs),
  Exercise(id: 'calf_raise', name: 'Calf Raise', muscleGroup: MuscleGroup.legs),
  Exercise(id: 'lunges', name: 'Lunges', muscleGroup: MuscleGroup.legs),
  Exercise(id: 'step_up', name: 'Step-Up', muscleGroup: MuscleGroup.legs),
  Exercise(id: 'hip_thrust', name: 'Hip Thrust', muscleGroup: MuscleGroup.legs),
  Exercise(id: 'sumo_deadlift', name: 'Sumo Deadlift', muscleGroup: MuscleGroup.legs),
  // ── Core ─────────────────────────────────────────────────────────────────
  Exercise(id: 'plank', name: 'Plank', muscleGroup: MuscleGroup.core),
  Exercise(id: 'crunch', name: 'Crunch', muscleGroup: MuscleGroup.core),
  Exercise(id: 'russian_twist', name: 'Russian Twist', muscleGroup: MuscleGroup.core),
  Exercise(id: 'dead_bug', name: 'Dead Bug', muscleGroup: MuscleGroup.core),
  Exercise(id: 'hanging_leg_raise', name: 'Hanging Leg Raise', muscleGroup: MuscleGroup.core),
  Exercise(id: 'ab_wheel', name: 'Ab Wheel Rollout', muscleGroup: MuscleGroup.core),
  Exercise(id: 'pallof_press', name: 'Pallof Press', muscleGroup: MuscleGroup.core),
  // ── Cardio ───────────────────────────────────────────────────────────────
  Exercise(id: 'running', name: 'Running', muscleGroup: MuscleGroup.cardio),
  Exercise(id: 'cycling', name: 'Cycling', muscleGroup: MuscleGroup.cardio),
  Exercise(id: 'rowing', name: 'Rowing Machine', muscleGroup: MuscleGroup.cardio),
  Exercise(id: 'jump_rope', name: 'Jump Rope', muscleGroup: MuscleGroup.cardio),
  Exercise(id: 'burpees', name: 'Burpees', muscleGroup: MuscleGroup.cardio),
  Exercise(id: 'box_jump', name: 'Box Jump', muscleGroup: MuscleGroup.cardio),
  Exercise(id: 'stair_climber', name: 'Stair Climber', muscleGroup: MuscleGroup.cardio),
  Exercise(id: 'elliptical', name: 'Elliptical', muscleGroup: MuscleGroup.cardio),
];
