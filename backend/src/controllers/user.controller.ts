import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { verifyJWT } from '../middlewares/auth.middleware';
import { calculateBMR } from '../utils/bmr';

const prisma = new PrismaClient();

export async function userRoutes(fastify: FastifyInstance) {
  // Apply JWT verification middleware to all routes in this plugin
  fastify.addHook('preHandler', verifyJWT);

  // GET /profile
  fastify.get('/profile', async (request, reply) => {
    const userId = request.user?.id;
    if (!userId) {
      reply.status(401).send({ message: 'Unauthorized' });
      return;
    }

    try {
      const user = await prisma.user.findUnique({
        where: { id: userId },
        include: {
          goals: {
            orderBy: { startDate: 'desc' },
            take: 1,
          },
        },
      });

      if (!user) {
        reply.status(404).send({ message: 'User profile not found' });
        return;
      }

      reply.send(user);
    } catch (error) {
      fastify.log.error(error);
      reply.status(500).send({ message: 'Internal server error fetching profile' });
    }
  });

  // PATCH /profile (Onboarding update)
  fastify.patch('/profile', async (request, reply) => {
    const userId = request.user?.id;
    if (!userId) {
      reply.status(401).send({ message: 'Unauthorized' });
      return;
    }

    const {
      gender,
      age,
      heightCm,
      weightKg,
      unitPreference,
      activityLevel,
      fitnessGoal,
    } = request.body as any;

    try {
      const parsedAge = parseInt(age, 10);
      const parsedHeight = parseFloat(heightCm);
      const parsedWeight = parseFloat(weightKg);

      if (isNaN(parsedAge) || isNaN(parsedHeight) || isNaN(parsedWeight)) {
        reply.status(400).send({ message: 'Invalid numeric fields for age, height, or weight' });
        return;
      }

      // Calculate BMR using our Mifflin-St Jeor utility
      const bmr = calculateBMR(gender, parsedAge, parsedHeight, parsedWeight);

      // Calculate TDEE from BMR × activity multiplier
      const activityMultipliers: Record<string, number> = {
        'Sedentary': 1.2,
        'Lightly Active': 1.375,
        'Moderately Active': 1.55,
        'Very Active': 1.725,
      };
      const multiplier = activityMultipliers[activityLevel] || 1.55;
      const tdee = bmr * multiplier;

      // Calculate dailyCalorieTarget and goalType based on fitnessGoal
      let dailyCalorieTarget = tdee;
      let goalType = 'maintain';
      if (fitnessGoal === 'weight_loss') {
        dailyCalorieTarget = tdee - 500;
        goalType = 'deficit';
      } else if (fitnessGoal === 'muscle_gain') {
        dailyCalorieTarget = tdee + 300;
        goalType = 'surplus';
      }

      // Upsert the user's calorie goal to prevent duplicates
      const existingGoal = await prisma.goal.findFirst({
        where: { userId },
      });

      if (existingGoal) {
        await prisma.goal.update({
          where: { id: existingGoal.id },
          data: {
            goalType,
            dailyCalorieTarget,
            startDate: new Date(),
          },
        });
      } else {
        await prisma.goal.create({
          data: {
            userId,
            goalType,
            dailyCalorieTarget,
            startDate: new Date(),
          },
        });
      }

      const updatedUser = await prisma.user.update({
        where: { id: userId },
        data: {
          gender,
          age: parsedAge,
          heightCm: parsedHeight,
          weightKg: parsedWeight,
          unitPreference: unitPreference || 'metric',
          activityLevel,
          fitnessGoal,
          bmr,
          tdee,
        },
        include: {
          goals: {
            orderBy: { startDate: 'desc' },
            take: 1,
          },
        },
      });

      reply.send(updatedUser);
    } catch (error) {
      fastify.log.error(error);
      reply.status(500).send({ message: 'Internal server error updating profile' });
    }
  });
}
