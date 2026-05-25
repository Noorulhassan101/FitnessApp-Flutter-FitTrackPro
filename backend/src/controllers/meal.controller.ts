import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { verifyJWT } from '../middlewares/auth.middleware';

const prisma = new PrismaClient();

export async function mealRoutes(fastify: FastifyInstance) {
  // Apply JWT verification middleware to all routes in this controller
  fastify.addHook('preHandler', verifyJWT);

  // GET / (List meals)
  fastify.get('/', async (request, reply) => {
    const userId = request.user?.id;
    if (!userId) {
      reply.status(401).send({ message: 'Unauthorized' });
      return;
    }

    try {
      const meals = await prisma.mealLog.findMany({
        where: { userId },
        orderBy: { loggedAt: 'desc' },
      });
      reply.send(meals);
    } catch (error) {
      fastify.log.error(error);
      reply.status(500).send({ message: 'Internal server error fetching meals' });
    }
  });

  // POST / (Create / Log meal)
  fastify.post('/', async (request, reply) => {
    const userId = request.user?.id;
    if (!userId) {
      reply.status(401).send({ message: 'Unauthorized' });
      return;
    }

    const {
      id,
      mealCategory,
      foodName,
      caloriesConsumed,
      loggedAt,
    } = request.body as any;

    if (!mealCategory || !foodName || caloriesConsumed === undefined || caloriesConsumed === null) {
      reply.status(400).send({ message: 'mealCategory, foodName, and caloriesConsumed are required' });
      return;
    }

    const calories = parseFloat(caloriesConsumed);

    try {
      const newMeal = await prisma.mealLog.upsert({
        where: { id: id || '' },
        update: {
          mealCategory,
          foodName,
          caloriesConsumed: calories,
          loggedAt: loggedAt ? new Date(loggedAt) : new Date(),
        },
        create: {
          id: id || undefined,
          userId,
          mealCategory,
          foodName,
          caloriesConsumed: calories,
          loggedAt: loggedAt ? new Date(loggedAt) : new Date(),
        },
      });

      reply.status(201).send(newMeal);
    } catch (error) {
      fastify.log.error(error);
      reply.status(500).send({ message: 'Internal server error logging meal' });
    }
  });

  // DELETE /:id (Delete meal)
  fastify.delete('/:id', async (request, reply) => {
    const userId = request.user?.id;
    const { id } = request.params as { id: string };

    if (!userId) {
      reply.status(401).send({ message: 'Unauthorized' });
      return;
    }

    try {
      const meal = await prisma.mealLog.findUnique({
        where: { id },
      });

      if (!meal) {
        reply.status(404).send({ message: 'Meal log not found' });
        return;
      }

      if (meal.userId !== userId) {
        reply.status(403).send({ message: 'Forbidden' });
        return;
      }

      await prisma.mealLog.delete({
        where: { id },
      });

      reply.send({ message: 'Meal log deleted successfully' });
    } catch (error) {
      fastify.log.error(error);
      reply.status(500).send({ message: 'Internal server error deleting meal' });
    }
  });
}
