/**
 * Seed file — 3 test users with profiles, subscriptions, food logs,
 * workout logs, body stats, and goals.
 *
 * Run with:  npm run db:seed  (from apps/backend)
 */

import { PrismaClient } from '@prisma/client';
import { hashPassword } from '../src/services/auth.service';

const prisma = new PrismaClient();

// ─── Helpers ─────────────────────────────────────────────────────────────────

function daysAgo(n: number): Date {
  const d = new Date();
  d.setDate(d.getDate() - n);
  d.setHours(8, 0, 0, 0);
  return d;
}

function hoursAgo(n: number): Date {
  return new Date(Date.now() - n * 60 * 60 * 1000);
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log('🌱  Seeding FitCore database...');

  // Pre-compute password hashes for test users (all use "Password123!")
  const testPassword = 'Password123!';
  const [aliceHash, marcusHash, samHash] = await Promise.all([
    hashPassword(testPassword),
    hashPassword(testPassword),
    hashPassword(testPassword),
  ]);

  // Wipe existing seed data (order matters for FK constraints)
  await prisma.exerciseSet.deleteMany();
  await prisma.workoutLog.deleteMany();
  await prisma.foodLog.deleteMany();
  await prisma.bodyStat.deleteMany();
  await prisma.goal.deleteMany();
  await prisma.subscription.deleteMany();
  await prisma.friendship.deleteMany();
  await prisma.userProfile.deleteMany();
  await prisma.user.deleteMany();

  // ─── User 1 — Alice (weight loss, Pro subscriber) ────────────────────────

  const alice = await prisma.user.create({
    data: {
      email: 'alice@fitcore.dev',
      name: 'Alice Chen',
      passwordHash: aliceHash,
      gender: 'female',
      heightCm: 165,
      dateOfBirth: new Date('1995-03-14'),
      profile: {
        create: {
          fitnessGoal: 'lose_weight',
          activityLevel: 'moderate',
          targetWeightKg: 60,
          tdee: 1980,
        },
      },
      subscription: {
        create: {
          tier: 'pro',
          stripeId: 'cus_test_alice',
          validUntil: new Date('2027-01-01'),
        },
      },
    },
  });

  // Alice's body stats (last 7 days)
  await prisma.bodyStat.createMany({
    data: [
      { userId: alice.id, weightKg: 68.4, bodyFatPct: 28.1, bmi: 25.1, measuredAt: daysAgo(6) },
      { userId: alice.id, weightKg: 68.1, bodyFatPct: 27.9, bmi: 25.0, measuredAt: daysAgo(3) },
      { userId: alice.id, weightKg: 67.8, bodyFatPct: 27.7, bmi: 24.9, measuredAt: daysAgo(0) },
    ],
  });

  // Alice's goals
  await prisma.goal.createMany({
    data: [
      { userId: alice.id, type: 'daily_calories', targetValue: 1480, currentValue: 1350 },
      { userId: alice.id, type: 'weekly_workouts', targetValue: 4, currentValue: 3 },
      { userId: alice.id, type: 'weight_target', targetValue: 60, currentValue: 67.8, deadline: new Date('2026-09-01') },
    ],
  });

  // Alice's food logs — today (breakfast + lunch + snack)
  await prisma.foodLog.createMany({
    data: [
      {
        userId: alice.id,
        foodId: 'opff_oats_rolled',
        foodName: 'Rolled Oats (cooked)',
        mealType: 'breakfast',
        servingG: 150,
        calories: 166,
        proteinG: 6,
        carbsG: 28,
        fatG: 3.5,
        fiberG: 4,
        loggedAt: daysAgo(0),
      },
      {
        userId: alice.id,
        foodId: 'opff_greek_yogurt',
        foodName: 'Greek Yogurt (plain, 0%)',
        mealType: 'breakfast',
        servingG: 200,
        calories: 116,
        proteinG: 20,
        carbsG: 8,
        fatG: 0.4,
        fiberG: 0,
        loggedAt: daysAgo(0),
      },
      {
        userId: alice.id,
        foodId: 'opff_chicken_breast',
        foodName: 'Chicken Breast (grilled)',
        mealType: 'lunch',
        servingG: 180,
        calories: 297,
        proteinG: 56,
        carbsG: 0,
        fatG: 6.5,
        fiberG: 0,
        loggedAt: daysAgo(0),
      },
      {
        userId: alice.id,
        foodId: 'opff_brown_rice',
        foodName: 'Brown Rice (cooked)',
        mealType: 'lunch',
        servingG: 200,
        calories: 218,
        proteinG: 4.5,
        carbsG: 46,
        fatG: 1.6,
        fiberG: 3.5,
        loggedAt: daysAgo(0),
      },
      {
        userId: alice.id,
        foodId: 'opff_almonds',
        foodName: 'Almonds',
        mealType: 'snack',
        servingG: 30,
        calories: 174,
        proteinG: 6,
        carbsG: 6,
        fatG: 15,
        fiberG: 3.5,
        loggedAt: daysAgo(0),
      },
    ],
  });

  // Alice's food logs — yesterday
  await prisma.foodLog.createMany({
    data: [
      {
        userId: alice.id,
        foodId: 'opff_eggs_scrambled',
        foodName: 'Scrambled Eggs (2 large)',
        mealType: 'breakfast',
        servingG: 120,
        calories: 182,
        proteinG: 14,
        carbsG: 2,
        fatG: 13,
        fiberG: 0,
        loggedAt: daysAgo(1),
      },
      {
        userId: alice.id,
        foodId: 'opff_salmon_fillet',
        foodName: 'Salmon Fillet (baked)',
        mealType: 'lunch',
        servingG: 150,
        calories: 280,
        proteinG: 38,
        carbsG: 0,
        fatG: 14,
        fiberG: 0,
        loggedAt: daysAgo(1),
      },
      {
        userId: alice.id,
        foodId: 'opff_sweet_potato',
        foodName: 'Sweet Potato (baked)',
        mealType: 'dinner',
        servingG: 200,
        calories: 172,
        proteinG: 3.2,
        carbsG: 40,
        fatG: 0.2,
        fiberG: 6,
        loggedAt: daysAgo(1),
      },
    ],
  });

  // Alice's workout log — today (upper body push)
  const aliceWorkout = await prisma.workoutLog.create({
    data: {
      userId: alice.id,
      name: 'Upper Body Push',
      startedAt: hoursAgo(2),
      finishedAt: hoursAgo(1),
      durationMin: 52,
      caloriesBurned: 230,
    },
  });

  await prisma.exerciseSet.createMany({
    data: [
      // Bench Press — 3 sets
      { workoutLogId: aliceWorkout.id, exerciseId: 'bench_press', exerciseName: 'Bench Press', setNumber: 1, reps: 10, weightKg: 40, rpe: 7 },
      { workoutLogId: aliceWorkout.id, exerciseId: 'bench_press', exerciseName: 'Bench Press', setNumber: 2, reps: 8, weightKg: 42.5, rpe: 8 },
      { workoutLogId: aliceWorkout.id, exerciseId: 'bench_press', exerciseName: 'Bench Press', setNumber: 3, reps: 7, weightKg: 42.5, rpe: 9 },
      // Overhead Press — 3 sets
      { workoutLogId: aliceWorkout.id, exerciseId: 'overhead_press', exerciseName: 'Overhead Press', setNumber: 1, reps: 10, weightKg: 25, rpe: 7 },
      { workoutLogId: aliceWorkout.id, exerciseId: 'overhead_press', exerciseName: 'Overhead Press', setNumber: 2, reps: 9, weightKg: 25, rpe: 8 },
      { workoutLogId: aliceWorkout.id, exerciseId: 'overhead_press', exerciseName: 'Overhead Press', setNumber: 3, reps: 8, weightKg: 25, rpe: 8 },
      // Tricep Pushdown — 3 sets
      { workoutLogId: aliceWorkout.id, exerciseId: 'tricep_pushdown', exerciseName: 'Tricep Pushdown', setNumber: 1, reps: 12, weightKg: 20, rpe: 6 },
      { workoutLogId: aliceWorkout.id, exerciseId: 'tricep_pushdown', exerciseName: 'Tricep Pushdown', setNumber: 2, reps: 12, weightKg: 20, rpe: 7 },
      { workoutLogId: aliceWorkout.id, exerciseId: 'tricep_pushdown', exerciseName: 'Tricep Pushdown', setNumber: 3, reps: 10, weightKg: 22.5, rpe: 8 },
    ],
  });

  // ─── User 2 — Marcus (muscle gain, Coach subscriber) ─────────────────────

  const marcus = await prisma.user.create({
    data: {
      email: 'marcus@fitcore.dev',
      name: 'Marcus Williams',
      passwordHash: marcusHash,
      gender: 'male',
      heightCm: 182,
      dateOfBirth: new Date('1990-07-22'),
      profile: {
        create: {
          fitnessGoal: 'build_muscle',
          activityLevel: 'active',
          targetWeightKg: 92,
          tdee: 3100,
        },
      },
      subscription: {
        create: {
          tier: 'coach',
          stripeId: 'cus_test_marcus',
          validUntil: new Date('2027-03-01'),
        },
      },
    },
  });

  await prisma.bodyStat.createMany({
    data: [
      { userId: marcus.id, weightKg: 86.2, bodyFatPct: 14.5, muscleMassKg: 68.1, bmi: 26.0, measuredAt: daysAgo(14) },
      { userId: marcus.id, weightKg: 86.8, bodyFatPct: 14.3, muscleMassKg: 68.6, bmi: 26.2, measuredAt: daysAgo(7) },
      { userId: marcus.id, weightKg: 87.3, bodyFatPct: 14.1, muscleMassKg: 69.2, bmi: 26.4, measuredAt: daysAgo(0) },
    ],
  });

  await prisma.goal.createMany({
    data: [
      { userId: marcus.id, type: 'daily_calories', targetValue: 3400, currentValue: 3250 },
      { userId: marcus.id, type: 'weekly_workouts', targetValue: 5, currentValue: 5, completed: true },
      { userId: marcus.id, type: 'weight_target', targetValue: 92, currentValue: 87.3, deadline: new Date('2026-12-31') },
    ],
  });

  // Marcus — today's high-protein intake
  await prisma.foodLog.createMany({
    data: [
      {
        userId: marcus.id,
        foodId: 'opff_whey_protein',
        foodName: 'Whey Protein Shake',
        mealType: 'breakfast',
        servingG: 40,
        calories: 160,
        proteinG: 30,
        carbsG: 8,
        fatG: 3,
        fiberG: 1,
        loggedAt: daysAgo(0),
      },
      {
        userId: marcus.id,
        foodId: 'opff_oats_rolled',
        foodName: 'Rolled Oats (cooked)',
        mealType: 'breakfast',
        servingG: 250,
        calories: 277,
        proteinG: 10,
        carbsG: 47,
        fatG: 5.8,
        fiberG: 7,
        loggedAt: daysAgo(0),
      },
      {
        userId: marcus.id,
        foodId: 'opff_chicken_breast',
        foodName: 'Chicken Breast (grilled)',
        mealType: 'lunch',
        servingG: 300,
        calories: 495,
        proteinG: 93,
        carbsG: 0,
        fatG: 10.8,
        fiberG: 0,
        loggedAt: daysAgo(0),
      },
      {
        userId: marcus.id,
        foodId: 'opff_white_rice',
        foodName: 'White Rice (cooked)',
        mealType: 'lunch',
        servingG: 350,
        calories: 455,
        proteinG: 8.4,
        carbsG: 99,
        fatG: 1,
        fiberG: 1.4,
        loggedAt: daysAgo(0),
      },
      {
        userId: marcus.id,
        foodId: 'opff_whole_eggs',
        foodName: 'Whole Eggs (boiled, 4)',
        mealType: 'snack',
        servingG: 200,
        calories: 286,
        proteinG: 25,
        carbsG: 2,
        fatG: 20,
        fiberG: 0,
        loggedAt: daysAgo(0),
      },
      {
        userId: marcus.id,
        foodId: 'opff_beef_mince',
        foodName: 'Lean Beef Mince (cooked)',
        mealType: 'dinner',
        servingG: 250,
        calories: 395,
        proteinG: 52,
        carbsG: 0,
        fatG: 20,
        fiberG: 0,
        loggedAt: daysAgo(0),
      },
    ],
  });

  // Marcus — leg day workout
  const marcusWorkout = await prisma.workoutLog.create({
    data: {
      userId: marcus.id,
      name: 'Leg Day — Squat Focus',
      startedAt: hoursAgo(5),
      finishedAt: hoursAgo(3.5),
      durationMin: 85,
      caloriesBurned: 420,
      notes: 'Hit a new PR on squats — 130kg for 5 reps',
    },
  });

  await prisma.exerciseSet.createMany({
    data: [
      // Squat — 5 sets (progressive overload)
      { workoutLogId: marcusWorkout.id, exerciseId: 'barbell_squat', exerciseName: 'Barbell Back Squat', setNumber: 1, reps: 5, weightKg: 100, rpe: 6 },
      { workoutLogId: marcusWorkout.id, exerciseId: 'barbell_squat', exerciseName: 'Barbell Back Squat', setNumber: 2, reps: 5, weightKg: 115, rpe: 7 },
      { workoutLogId: marcusWorkout.id, exerciseId: 'barbell_squat', exerciseName: 'Barbell Back Squat', setNumber: 3, reps: 5, weightKg: 125, rpe: 8 },
      { workoutLogId: marcusWorkout.id, exerciseId: 'barbell_squat', exerciseName: 'Barbell Back Squat', setNumber: 4, reps: 5, weightKg: 130, rpe: 9 },
      { workoutLogId: marcusWorkout.id, exerciseId: 'barbell_squat', exerciseName: 'Barbell Back Squat', setNumber: 5, reps: 3, weightKg: 130, rpe: 9 },
      // Romanian Deadlift — 4 sets
      { workoutLogId: marcusWorkout.id, exerciseId: 'rdl', exerciseName: 'Romanian Deadlift', setNumber: 1, reps: 10, weightKg: 90, rpe: 7 },
      { workoutLogId: marcusWorkout.id, exerciseId: 'rdl', exerciseName: 'Romanian Deadlift', setNumber: 2, reps: 10, weightKg: 100, rpe: 8 },
      { workoutLogId: marcusWorkout.id, exerciseId: 'rdl', exerciseName: 'Romanian Deadlift', setNumber: 3, reps: 8, weightKg: 100, rpe: 8 },
      { workoutLogId: marcusWorkout.id, exerciseId: 'rdl', exerciseName: 'Romanian Deadlift', setNumber: 4, reps: 8, weightKg: 100, rpe: 9 },
      // Leg Press — 3 sets
      { workoutLogId: marcusWorkout.id, exerciseId: 'leg_press', exerciseName: 'Leg Press', setNumber: 1, reps: 12, weightKg: 180, rpe: 7 },
      { workoutLogId: marcusWorkout.id, exerciseId: 'leg_press', exerciseName: 'Leg Press', setNumber: 2, reps: 12, weightKg: 200, rpe: 8 },
      { workoutLogId: marcusWorkout.id, exerciseId: 'leg_press', exerciseName: 'Leg Press', setNumber: 3, reps: 10, weightKg: 200, rpe: 9 },
    ],
  });

  // ─── User 3 — Sam (maintenance, Free tier) ───────────────────────────────

  const sam = await prisma.user.create({
    data: {
      email: 'sam@fitcore.dev',
      name: 'Sam Okafor',
      passwordHash: samHash,
      gender: 'male',
      heightCm: 175,
      dateOfBirth: new Date('1998-11-05'),
      profile: {
        create: {
          fitnessGoal: 'maintain',
          activityLevel: 'light',
          targetWeightKg: null,
          tdee: 2200,
        },
      },
      subscription: {
        create: {
          tier: 'free',
          stripeId: null,
          validUntil: null,
        },
      },
    },
  });

  await prisma.bodyStat.createMany({
    data: [
      { userId: sam.id, weightKg: 72.0, bmi: 23.5, measuredAt: daysAgo(10) },
      { userId: sam.id, weightKg: 72.2, bmi: 23.6, measuredAt: daysAgo(0) },
    ],
  });

  await prisma.goal.createMany({
    data: [
      { userId: sam.id, type: 'daily_calories', targetValue: 2200, currentValue: 1850 },
      { userId: sam.id, type: 'weekly_workouts', targetValue: 3, currentValue: 1 },
    ],
  });

  // Sam — light food day
  await prisma.foodLog.createMany({
    data: [
      {
        userId: sam.id,
        foodId: 'opff_banana',
        foodName: 'Banana (medium)',
        mealType: 'breakfast',
        servingG: 120,
        calories: 107,
        proteinG: 1.3,
        carbsG: 27,
        fatG: 0.4,
        fiberG: 3.1,
        loggedAt: daysAgo(0),
      },
      {
        userId: sam.id,
        foodId: 'opff_peanut_butter',
        foodName: 'Peanut Butter (2 tbsp)',
        mealType: 'breakfast',
        servingG: 32,
        calories: 190,
        proteinG: 8,
        carbsG: 6,
        fatG: 16,
        fiberG: 2,
        loggedAt: daysAgo(0),
      },
      {
        userId: sam.id,
        foodId: 'opff_pasta_cooked',
        foodName: 'Penne Pasta (cooked)',
        mealType: 'lunch',
        servingG: 280,
        calories: 352,
        proteinG: 12.6,
        carbsG: 71,
        fatG: 1.7,
        fiberG: 4.2,
        loggedAt: daysAgo(0),
      },
      {
        userId: sam.id,
        foodId: 'opff_tomato_sauce',
        foodName: 'Tomato Pasta Sauce',
        mealType: 'lunch',
        servingG: 150,
        calories: 75,
        proteinG: 2.8,
        carbsG: 14,
        fatG: 1.5,
        fiberG: 2.5,
        loggedAt: daysAgo(0),
      },
    ],
  });

  // Sam — short cardio run
  const samWorkout = await prisma.workoutLog.create({
    data: {
      userId: sam.id,
      name: '5K Morning Run',
      startedAt: hoursAgo(10),
      finishedAt: hoursAgo(9.5),
      durationMin: 28,
      caloriesBurned: 290,
    },
  });

  await prisma.exerciseSet.createMany({
    data: [
      {
        workoutLogId: samWorkout.id,
        exerciseId: 'outdoor_run',
        exerciseName: 'Outdoor Run',
        setNumber: 1,
        durationSec: 1680,
        distanceM: 5000,
        rpe: 6,
      },
    ],
  });

  // ─── Friendships ──────────────────────────────────────────────────────────

  await prisma.friendship.createMany({
    data: [
      { userId: alice.id, friendId: marcus.id, status: 'accepted' },
      { userId: marcus.id, friendId: alice.id, status: 'accepted' },
      { userId: sam.id, friendId: alice.id, status: 'pending' },
    ],
  });

  // ─── Summary ─────────────────────────────────────────────────────────────

  const userCount = await prisma.user.count();
  const foodLogCount = await prisma.foodLog.count();
  const workoutCount = await prisma.workoutLog.count();
  const setCount = await prisma.exerciseSet.count();

  console.log(`✅  Seeding complete:`);
  console.log(`   Users:         ${userCount}`);
  console.log(`   Food logs:     ${foodLogCount}`);
  console.log(`   Workout logs:  ${workoutCount}`);
  console.log(`   Exercise sets: ${setCount}`);
}

main()
  .catch((err) => {
    console.error('❌  Seed failed:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
