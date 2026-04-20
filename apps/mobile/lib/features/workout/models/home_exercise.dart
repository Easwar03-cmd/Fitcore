import 'package:flutter/material.dart';

import 'exercise.dart';

enum HomeWorkoutCategory { push, pull, legs, core, fullBody, skill }

extension HomeWorkoutCategoryX on HomeWorkoutCategory {
  String get label => switch (this) {
        HomeWorkoutCategory.push => 'Push',
        HomeWorkoutCategory.pull => 'Pull',
        HomeWorkoutCategory.legs => 'Legs',
        HomeWorkoutCategory.core => 'Core',
        HomeWorkoutCategory.fullBody => 'Full Body',
        HomeWorkoutCategory.skill => 'Skill',
      };

  IconData get icon => switch (this) {
        HomeWorkoutCategory.push => Icons.fitness_center,
        HomeWorkoutCategory.pull => Icons.arrow_upward_rounded,
        HomeWorkoutCategory.legs => Icons.directions_run_rounded,
        HomeWorkoutCategory.core => Icons.rotate_90_degrees_ccw_rounded,
        HomeWorkoutCategory.fullBody => Icons.sports_gymnastics_rounded,
        HomeWorkoutCategory.skill => Icons.stars_rounded,
      };

  Color get color => switch (this) {
        HomeWorkoutCategory.push => const Color(0xFFE53E3E),
        HomeWorkoutCategory.pull => const Color(0xFF3182CE),
        HomeWorkoutCategory.legs => const Color(0xFFD69E2E),
        HomeWorkoutCategory.core => const Color(0xFF319795),
        HomeWorkoutCategory.fullBody => const Color(0xFF805AD5),
        HomeWorkoutCategory.skill => const Color(0xFFDD6B20),
      };
}

enum HomeDifficulty { beginner, intermediate, advanced }

extension HomeDifficultyX on HomeDifficulty {
  String get label => switch (this) {
        HomeDifficulty.beginner => 'Beginner',
        HomeDifficulty.intermediate => 'Intermediate',
        HomeDifficulty.advanced => 'Advanced',
      };

  Color get color => switch (this) {
        HomeDifficulty.beginner => const Color(0xFF38A169),
        HomeDifficulty.intermediate => const Color(0xFFD69E2E),
        HomeDifficulty.advanced => const Color(0xFFE53E3E),
      };
}

class HomeExercise {
  const HomeExercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.category,
    required this.difficulty,
    required this.description,
    this.cues = const [],
    this.timedOnly = false,
  });

  final String id;
  final String name;
  final MuscleGroup muscleGroup;
  final HomeWorkoutCategory category;
  final HomeDifficulty difficulty;
  final String description;
  final List<String> cues;

  /// If true the logger shows a duration (seconds) field instead of reps.
  final bool timedOnly;

  Exercise toExercise() => Exercise(
        id: id,
        name: name,
        muscleGroup: muscleGroup,
        isBodyweight: true,
        timedOnly: timedOnly,
      );
}

// ── Home exercise library ─────────────────────────────────────────────────────

const kHomeExerciseLibrary = <HomeExercise>[
  // ── Push ─────────────────────────────────────────────────────────────────
  HomeExercise(
    id: 'push_up_bw', name: 'Push-Up',
    muscleGroup: MuscleGroup.chest, category: HomeWorkoutCategory.push,
    difficulty: HomeDifficulty.beginner,
    description: 'Classic upper-body push movement targeting chest, shoulders and triceps.',
    cues: ['Hands slightly wider than shoulders', 'Body in a straight line', 'Lower chest to floor', 'Elbows at 45°'],
  ),
  HomeExercise(
    id: 'wide_push_up', name: 'Wide Push-Up',
    muscleGroup: MuscleGroup.chest, category: HomeWorkoutCategory.push,
    difficulty: HomeDifficulty.beginner,
    description: 'Wider hand placement shifts emphasis to the outer chest.',
    cues: ['Hands 1.5× shoulder-width', 'Keep core tight', 'Full range of motion'],
  ),
  HomeExercise(
    id: 'diamond_push_up', name: 'Diamond Push-Up',
    muscleGroup: MuscleGroup.arms, category: HomeWorkoutCategory.push,
    difficulty: HomeDifficulty.intermediate,
    description: 'Narrow diamond grip targets triceps and inner chest heavily.',
    cues: ['Thumbs and index fingers form a diamond', 'Keep elbows close', 'Lower slowly'],
  ),
  HomeExercise(
    id: 'pike_push_up', name: 'Pike Push-Up',
    muscleGroup: MuscleGroup.shoulders, category: HomeWorkoutCategory.push,
    difficulty: HomeDifficulty.intermediate,
    description: 'Hips high, body in inverted V — loads the shoulders like an overhead press.',
    cues: ['Walk feet in to raise hips', 'Lower crown toward floor', 'Press back to top'],
  ),
  HomeExercise(
    id: 'decline_push_up', name: 'Decline Push-Up',
    muscleGroup: MuscleGroup.chest, category: HomeWorkoutCategory.push,
    difficulty: HomeDifficulty.intermediate,
    description: 'Feet elevated on a chair — hits the upper chest and front delts.',
    cues: ['Feet on a stable surface 30–60 cm high', 'Straight line from head to heels'],
  ),
  HomeExercise(
    id: 'archer_push_up', name: 'Archer Push-Up',
    muscleGroup: MuscleGroup.chest, category: HomeWorkoutCategory.push,
    difficulty: HomeDifficulty.advanced,
    description: 'Unilateral push-up variation — huge chest and tricep overload.',
    cues: ['One arm straight out to side', 'Lower toward the bent arm', 'Alternate sides each rep'],
  ),
  HomeExercise(
    id: 'dip_bw', name: 'Dip',
    muscleGroup: MuscleGroup.arms, category: HomeWorkoutCategory.push,
    difficulty: HomeDifficulty.intermediate,
    description: 'Parallel bar or chair dip targeting triceps and lower chest.',
    cues: ['Lean forward for chest, upright for triceps', 'Lower until upper arm is parallel', 'Lock out at top'],
  ),
  HomeExercise(
    id: 'handstand_push_up', name: 'Handstand Push-Up',
    muscleGroup: MuscleGroup.shoulders, category: HomeWorkoutCategory.push,
    difficulty: HomeDifficulty.advanced,
    description: 'Wall-assisted inverted press — maximum shoulder strength demand.',
    cues: ['Kick up against wall', 'Lower crown toward floor slowly', 'Engage core throughout'],
  ),

  // ── Pull ─────────────────────────────────────────────────────────────────
  HomeExercise(
    id: 'pull_up_bw', name: 'Pull-Up',
    muscleGroup: MuscleGroup.back, category: HomeWorkoutCategory.pull,
    difficulty: HomeDifficulty.intermediate,
    description: 'Overhand grip pull — primary lat and upper back builder.',
    cues: ['Grip just outside shoulders', 'Pull elbows down and back', 'Chin clears bar at top'],
  ),
  HomeExercise(
    id: 'chin_up', name: 'Chin-Up',
    muscleGroup: MuscleGroup.back, category: HomeWorkoutCategory.pull,
    difficulty: HomeDifficulty.intermediate,
    description: 'Underhand grip — lats plus strong bicep engagement.',
    cues: ['Shoulder-width underhand grip', 'Supinate wrists as you pull', 'Full hang at bottom'],
  ),
  HomeExercise(
    id: 'australian_pull_up', name: 'Australian Pull-Up',
    muscleGroup: MuscleGroup.back, category: HomeWorkoutCategory.pull,
    difficulty: HomeDifficulty.beginner,
    description: 'Horizontal row using a low bar or table — great pull-up precursor.',
    cues: ['Body straight and rigid', 'Pull chest to bar', 'Control the descent'],
  ),
  HomeExercise(
    id: 'negative_pull_up', name: 'Negative Pull-Up',
    muscleGroup: MuscleGroup.back, category: HomeWorkoutCategory.pull,
    difficulty: HomeDifficulty.beginner,
    description: 'Jump to top position, lower yourself over 3–5 seconds. Best pull-up builder.',
    cues: ['Jump or step to chin-over-bar position', 'Lower in 3–5 s', 'Repeat from jump'],
  ),
  HomeExercise(
    id: 'commando_pull_up', name: 'Commando Pull-Up',
    muscleGroup: MuscleGroup.back, category: HomeWorkoutCategory.pull,
    difficulty: HomeDifficulty.advanced,
    description: 'Neutral parallel grip, alternating head side each rep.',
    cues: ['Grip bar like a sword', 'Pull to one side of bar, then the other', 'Keep core tight'],
  ),
  HomeExercise(
    id: 'typewriter_pull_up', name: 'Typewriter Pull-Up',
    muscleGroup: MuscleGroup.back, category: HomeWorkoutCategory.pull,
    difficulty: HomeDifficulty.advanced,
    description: 'Pull up then slide laterally to each side at the top — brutal.',
    cues: ['Pull to one arm at top', 'Slide across to opposite arm', 'One rep = both sides'],
  ),

  // ── Legs ─────────────────────────────────────────────────────────────────
  HomeExercise(
    id: 'bw_squat', name: 'Bodyweight Squat',
    muscleGroup: MuscleGroup.legs, category: HomeWorkoutCategory.legs,
    difficulty: HomeDifficulty.beginner,
    description: 'Fundamental lower body movement — quads, glutes, hamstrings.',
    cues: ['Feet shoulder-width, toes out 15°', 'Knees track over toes', 'Hit parallel depth'],
  ),
  HomeExercise(
    id: 'jump_squat', name: 'Jump Squat',
    muscleGroup: MuscleGroup.legs, category: HomeWorkoutCategory.legs,
    difficulty: HomeDifficulty.intermediate,
    description: 'Explosive version of squat — power and conditioning.',
    cues: ['Squat to parallel', 'Explode through heels', 'Soft landing, immediately descend'],
  ),
  HomeExercise(
    id: 'lunge_bw', name: 'Lunge',
    muscleGroup: MuscleGroup.legs, category: HomeWorkoutCategory.legs,
    difficulty: HomeDifficulty.beginner,
    description: 'Single-leg pattern for quad and glute balance.',
    cues: ['Step forward, back knee hovers over floor', 'Front shin vertical', 'Drive through front heel'],
  ),
  HomeExercise(
    id: 'bulgarian_split_squat_bw', name: 'Bulgarian Split Squat',
    muscleGroup: MuscleGroup.legs, category: HomeWorkoutCategory.legs,
    difficulty: HomeDifficulty.intermediate,
    description: 'Rear foot elevated — intense single-leg quad and glute load.',
    cues: ['Rear foot on chair/bench', 'Front foot far enough forward', 'Lower until back knee near floor'],
  ),
  HomeExercise(
    id: 'pistol_squat', name: 'Pistol Squat',
    muscleGroup: MuscleGroup.legs, category: HomeWorkoutCategory.legs,
    difficulty: HomeDifficulty.advanced,
    description: 'Full single-leg squat to the floor — elite balance and strength.',
    cues: ['Extend one leg forward', 'Sit all the way down on one leg', 'Drive through heel to stand'],
  ),
  HomeExercise(
    id: 'glute_bridge_bw', name: 'Glute Bridge',
    muscleGroup: MuscleGroup.legs, category: HomeWorkoutCategory.legs,
    difficulty: HomeDifficulty.beginner,
    description: 'Supine hip extension — targets glutes and hamstrings.',
    cues: ['Feet flat, hip-width', 'Drive hips to ceiling', 'Squeeze glutes at top', 'Lower with control'],
  ),
  HomeExercise(
    id: 'nordic_curl', name: 'Nordic Hamstring Curl',
    muscleGroup: MuscleGroup.legs, category: HomeWorkoutCategory.legs,
    difficulty: HomeDifficulty.advanced,
    description: 'Kneel with feet anchored, lower torso slowly — extreme hamstring load.',
    cues: ['Anchor feet under sofa', 'Lower body in one rigid plank', 'Use hands to push back up'],
  ),
  HomeExercise(
    id: 'wall_sit', name: 'Wall Sit',
    muscleGroup: MuscleGroup.legs, category: HomeWorkoutCategory.legs,
    difficulty: HomeDifficulty.beginner,
    description: 'Isometric quad hold against a wall. Log duration in seconds.',
    cues: ['Back flat on wall', 'Thighs parallel to floor', '90° at knee and hip'],
    timedOnly: true,
  ),
  HomeExercise(
    id: 'calf_raise_bw', name: 'Calf Raise',
    muscleGroup: MuscleGroup.legs, category: HomeWorkoutCategory.legs,
    difficulty: HomeDifficulty.beginner,
    description: 'Standing or on step — isolates gastrocnemius and soleus.',
    cues: ['Full range: deep stretch at bottom', 'Pause and squeeze at top', 'Single-leg for more load'],
  ),

  // ── Core ─────────────────────────────────────────────────────────────────
  HomeExercise(
    id: 'plank_bw', name: 'Plank',
    muscleGroup: MuscleGroup.core, category: HomeWorkoutCategory.core,
    difficulty: HomeDifficulty.beginner,
    description: 'Isometric full-body tension hold. Log duration in seconds.',
    cues: ['Forearms under shoulders', 'Hips in line with shoulders', 'Breathe steadily', 'No sagging or piking'],
    timedOnly: true,
  ),
  HomeExercise(
    id: 'side_plank_bw', name: 'Side Plank',
    muscleGroup: MuscleGroup.core, category: HomeWorkoutCategory.core,
    difficulty: HomeDifficulty.beginner,
    description: 'Lateral isometric hold for obliques and lateral stability.',
    cues: ['Elbow under shoulder', 'Hips stacked', 'Hold each side separately'],
    timedOnly: true,
  ),
  HomeExercise(
    id: 'hollow_body', name: 'Hollow Body Hold',
    muscleGroup: MuscleGroup.core, category: HomeWorkoutCategory.core,
    difficulty: HomeDifficulty.intermediate,
    description: 'Gymnastics core position — the foundation of all calisthenics skills.',
    cues: ['Lower back pressed to floor', 'Arms and legs extended low', 'Ribs down, posterior pelvic tilt'],
    timedOnly: true,
  ),
  HomeExercise(
    id: 'mountain_climber', name: 'Mountain Climber',
    muscleGroup: MuscleGroup.core, category: HomeWorkoutCategory.core,
    difficulty: HomeDifficulty.beginner,
    description: 'Dynamic plank with alternating knee drives — core and cardio.',
    cues: ['Start in high plank', 'Drive knees toward chest alternately', 'Keep hips level'],
  ),
  HomeExercise(
    id: 'leg_raise_bw', name: 'Leg Raise',
    muscleGroup: MuscleGroup.core, category: HomeWorkoutCategory.core,
    difficulty: HomeDifficulty.beginner,
    description: 'Supine or hanging lower ab isolation.',
    cues: ['Lower back stays pressed down', 'Lower legs slowly', 'Do not swing or use momentum'],
  ),
  HomeExercise(
    id: 'v_up', name: 'V-Up',
    muscleGroup: MuscleGroup.core, category: HomeWorkoutCategory.core,
    difficulty: HomeDifficulty.intermediate,
    description: 'Full-body crunch — upper and lower abs meet in the middle.',
    cues: ['Arms and legs straight', 'Lift simultaneously', 'Touch toes at top'],
  ),
  HomeExercise(
    id: 'russian_twist_bw', name: 'Russian Twist',
    muscleGroup: MuscleGroup.core, category: HomeWorkoutCategory.core,
    difficulty: HomeDifficulty.beginner,
    description: 'Seated rotation targeting obliques.',
    cues: ['Lean back 45°', 'Feet off floor for harder version', 'Rotate fully each side = 1 rep'],
  ),
  HomeExercise(
    id: 'ab_wheel_bw', name: 'Ab Wheel Rollout',
    muscleGroup: MuscleGroup.core, category: HomeWorkoutCategory.core,
    difficulty: HomeDifficulty.advanced,
    description: 'Roll out from kneeling or standing — extreme anti-extension core demand.',
    cues: ['From knees first', 'Keep hips in line', 'Pull back using abs, not hip flexors'],
  ),
  HomeExercise(
    id: 'dragon_flag', name: 'Dragon Flag',
    muscleGroup: MuscleGroup.core, category: HomeWorkoutCategory.core,
    difficulty: HomeDifficulty.advanced,
    description: 'Bruce Lee favourite — lever your entire body on your upper back.',
    cues: ['Grip bench behind head', 'Keep body rigid', 'Lower as slowly as possible'],
  ),
  HomeExercise(
    id: 'l_sit', name: 'L-Sit',
    muscleGroup: MuscleGroup.core, category: HomeWorkoutCategory.core,
    difficulty: HomeDifficulty.advanced,
    description: 'Isometric hold with legs parallel to floor on parallel bars or floor.',
    cues: ['Depress and protract scapulae', 'Legs locked straight', 'Accumulate time in smaller holds'],
    timedOnly: true,
  ),

  // ── Full Body ─────────────────────────────────────────────────────────────
  HomeExercise(
    id: 'burpee_bw', name: 'Burpee',
    muscleGroup: MuscleGroup.cardio, category: HomeWorkoutCategory.fullBody,
    difficulty: HomeDifficulty.intermediate,
    description: 'Squat thrust with jump — full body conditioning staple.',
    cues: ['Squat, jump feet back, push-up, jump feet forward, jump up', 'Scale: step instead of jump'],
  ),
  HomeExercise(
    id: 'jumping_jack', name: 'Jumping Jack',
    muscleGroup: MuscleGroup.cardio, category: HomeWorkoutCategory.fullBody,
    difficulty: HomeDifficulty.beginner,
    description: 'Simple full-body warm-up and conditioning movement.',
    cues: ['Jump feet out as arms rise overhead', 'Return to start', 'Keep rhythm steady'],
  ),
  HomeExercise(
    id: 'bear_crawl', name: 'Bear Crawl',
    muscleGroup: MuscleGroup.core, category: HomeWorkoutCategory.fullBody,
    difficulty: HomeDifficulty.beginner,
    description: 'Quadrupedal movement — shoulders, core, hip stability.',
    cues: ['Knees 2 cm off floor', 'Opposite hand + foot move together', 'Keep back flat'],
  ),

  // ── Skill ─────────────────────────────────────────────────────────────────
  HomeExercise(
    id: 'handstand_hold', name: 'Handstand Hold',
    muscleGroup: MuscleGroup.shoulders, category: HomeWorkoutCategory.skill,
    difficulty: HomeDifficulty.advanced,
    description: 'Wall-assisted or freestanding shoulder and wrist strength/balance.',
    cues: ['Kick up against wall', 'Scapulae elevated', 'Fingertip balance corrections'],
    timedOnly: true,
  ),
  HomeExercise(
    id: 'muscle_up', name: 'Muscle-Up',
    muscleGroup: MuscleGroup.back, category: HomeWorkoutCategory.skill,
    difficulty: HomeDifficulty.advanced,
    description: 'Pull-up transitioning above the bar into a dip — requires false grip.',
    cues: ['False grip on bar', 'Explosive pull, lean forward at transition', 'Push to full lockout'],
  ),
  HomeExercise(
    id: 'front_lever', name: 'Front Lever',
    muscleGroup: MuscleGroup.back, category: HomeWorkoutCategory.skill,
    difficulty: HomeDifficulty.advanced,
    description: 'Horizontal body hold facing up — massive back and core strength.',
    cues: ['Start with tuck, progress to straddle, then full', 'Retract and depress scapulae', 'Arms locked'],
    timedOnly: true,
  ),
  HomeExercise(
    id: 'back_lever', name: 'Back Lever',
    muscleGroup: MuscleGroup.back, category: HomeWorkoutCategory.skill,
    difficulty: HomeDifficulty.advanced,
    description: 'Horizontal body hold facing down — shoulder and back extension.',
    cues: ['Skin-the-cat to inverted position', 'Lower to horizontal slowly', 'Tuck first, then extend'],
    timedOnly: true,
  ),
];
