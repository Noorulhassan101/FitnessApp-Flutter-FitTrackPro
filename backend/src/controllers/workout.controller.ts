import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { verifyJWT } from '../middlewares/auth.middleware';

const prisma = new PrismaClient();

const ACTIVITY_METS: Record<string, number> = {
  'Running': 9.8,
  'Cycling': 7.5,
  'Swimming': 6.0,
  'Weightlifting': 5.0,
  'Walking': 3.5,
  'Yoga': 2.5,
  'Other': 4.0,
};

export async function workoutRoutes(fastify: FastifyInstance) {
  // Apply JWT verification middleware to all routes in this controller
  fastify.addHook('preHandler', verifyJWT);

  // GET / (List workouts)
  fastify.get('/', async (request, reply) => {
    const userId = request.user?.id;
    if (!userId) {
      reply.status(401).send({ message: 'Unauthorized' });
      return;
    }

    try {
      const workouts = await prisma.workoutLog.findMany({
        where: { userId },
        orderBy: { loggedAt: 'desc' },
      });
      reply.send(workouts);
    } catch (error) {
      fastify.log.error(error);
      reply.status(500).send({ message: 'Internal server error fetching workouts' });
    }
  });

  // POST / (Create / Log workout)
  fastify.post('/', async (request, reply) => {
    const userId = request.user?.id;
    if (!userId) {
      reply.status(401).send({ message: 'Unauthorized' });
      return;
    }

    const {
      id,
      activityType,
      durationMin,
      caloriesBurned,
      metEstimate,
      notes,
      loggedAt,
    } = request.body as any;

    if (!activityType || !durationMin) {
      reply.status(400).send({ message: 'activityType and durationMin are required' });
      return;
    }

    try {
      // Find the user's weight to calculate estimated calories if needed
      const user = await prisma.user.findUnique({
        where: { id: userId },
      });

      const userWeight = user?.weightKg || 70.0; // default fallback weight

      const computedMet = metEstimate !== undefined && metEstimate !== null
        ? parseFloat(metEstimate)
        : (ACTIVITY_METS[activityType] || ACTIVITY_METS['Other']);

      const computedCalories = caloriesBurned !== undefined && caloriesBurned !== null
        ? parseFloat(caloriesBurned)
        : Math.round(computedMet * userWeight * (parseInt(durationMin, 10) / 60.0) * 10) / 10;

      const newWorkout = await prisma.workoutLog.upsert({
        where: { id: id || '' },
        update: {
          activityType,
          durationMin: parseInt(durationMin, 10),
          caloriesBurned: computedCalories,
          metEstimate: computedMet,
          notes: notes || null,
          loggedAt: loggedAt ? new Date(loggedAt) : new Date(),
        },
        create: {
          id: id || undefined,
          userId,
          activityType,
          durationMin: parseInt(durationMin, 10),
          caloriesBurned: computedCalories,
          metEstimate: computedMet,
          notes: notes || null,
          loggedAt: loggedAt ? new Date(loggedAt) : new Date(),
        },
      });

      reply.status(201).send(newWorkout);
    } catch (error) {
      fastify.log.error(error);
      reply.status(500).send({ message: 'Internal server error logging workout' });
    }
  });

  // DELETE /:id (Delete workout)
  fastify.delete('/:id', async (request, reply) => {
    const userId = request.user?.id;
    const { id } = request.params as { id: string };

    if (!userId) {
      reply.status(401).send({ message: 'Unauthorized' });
      return;
    }

    try {
      const workout = await prisma.workoutLog.findUnique({
        where: { id },
      });

      if (!workout) {
        reply.status(404).send({ message: 'Workout log not found' });
        return;
      }

      if (workout.userId !== userId) {
        reply.status(403).send({ message: 'Forbidden' });
        return;
      }

      await prisma.workoutLog.delete({
        where: { id },
      });

      reply.send({ message: 'Workout log deleted successfully' });
    } catch (error) {
      fastify.log.error(error);
      reply.status(500).send({ message: 'Internal server error deleting workout' });
    }
  });
}
