import { prisma } from '../utils/db';

type CreateSetData = {
  exerciseId: string;
  exerciseName: string;
  setNumber: number;
  reps?: number;
  weightKg?: number;
  durationSec?: number;
};

export type CreateWorkoutLogData = {
  userId: string;
  name: string;
  startedAt: Date;
  finishedAt?: Date;
  durationMin?: number;
  caloriesBurned?: number;
  distanceM?: number;
  routePolyline?: string;
  sets: CreateSetData[];
};

export const workoutRepository = {
  createWorkoutLog: (data: CreateWorkoutLogData) =>
    prisma.workoutLog.create({
      data: {
        userId: data.userId,
        name: data.name,
        startedAt: data.startedAt,
        finishedAt: data.finishedAt,
        durationMin: data.durationMin,
        caloriesBurned: data.caloriesBurned,
        distanceM: data.distanceM,
        routePolyline: data.routePolyline,
        sets: { create: data.sets },
      },
      include: { sets: { orderBy: { setNumber: 'asc' } } },
    }),

  getWorkoutLogs: (userId: string) =>
    prisma.workoutLog.findMany({
      where: { userId },
      include: { sets: { orderBy: { setNumber: 'asc' } } },
      orderBy: { startedAt: 'desc' },
      take: 20,
    }),
};
