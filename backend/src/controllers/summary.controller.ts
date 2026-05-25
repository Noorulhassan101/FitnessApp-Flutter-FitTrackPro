import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { verifyJWT } from '../middlewares/auth.middleware';

const prisma = new PrismaClient();

export async function summaryRoutes(fastify: FastifyInstance) {
  // Apply JWT verification middleware to all routes in this controller
  fastify.addHook('preHandler', verifyJWT);

  // GET /history (Get past 7 days daily summaries and current logging streak)
  fastify.get('/history', async (request, reply) => {
    const userId = request.user?.id;
    if (!userId) {
      reply.status(401).send({ message: 'Unauthorized' });
      return;
    }

    try {
      // 1. Fetch user's profile to get daily calorie target (TDEE-based)
      const user = await prisma.user.findUnique({
        where: { id: userId },
      });

      if (!user) {
        reply.status(404).send({ message: 'User not found' });
        return;
      }

      // Calculate base target
      const tdee = user.tdee || 2000.0;
      let baseTarget = tdee;
      if (user.fitnessGoal === 'deficit') {
        baseTarget = tdee - 500;
      } else if (user.fitnessGoal === 'surplus') {
        baseTarget = tdee + 300;
      }

      // 2. Fetch summaries, meals, and workouts logged in the last 7 days
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
      sevenDaysAgo.setHours(0, 0, 0, 0);

      const existingSummaries = await prisma.dailySummary.findMany({
        where: {
          userId,
          date: { gte: sevenDaysAgo },
        },
      });

      const meals = await prisma.mealLog.findMany({
        where: {
          userId,
          loggedAt: { gte: sevenDaysAgo },
        },
      });

      const workouts = await prisma.workoutLog.findMany({
        where: {
          userId,
          loggedAt: { gte: sevenDaysAgo },
        },
      });

      // 3. Group by date string (YYYY-MM-DD)
      const summaryMap = new Map<string, {
        date: string;
        totalCaloriesConsumed: number;
        totalCaloriesBurned: number;
        netCalories: number;
        steps: number;
        activeCalories: number;
      }>();

      // Initialize summary map for the last 7 days (including today)
      for (let i = 6; i >= 0; i--) {
        const d = new Date();
        d.setDate(d.getDate() - i);
        const dateStr = d.toISOString().split('T')[0];

        const matchingDb = existingSummaries.find(
          s => new Date(s.date).toISOString().split('T')[0] === dateStr
        );

        summaryMap.set(dateStr, {
          date: dateStr,
          totalCaloriesConsumed: 0,
          totalCaloriesBurned: matchingDb ? matchingDb.activeCalories : 0.0,
          netCalories: 0.0,
          steps: matchingDb ? matchingDb.steps : 0,
          activeCalories: matchingDb ? matchingDb.activeCalories : 0.0,
        });
      }

      // Populate meals
      for (const meal of meals) {
        const dateStr = new Date(meal.loggedAt).toISOString().split('T')[0];
        const daySummary = summaryMap.get(dateStr);
        if (daySummary) {
          daySummary.totalCaloriesConsumed += meal.caloriesConsumed;
        }
      }

      // Populate workouts
      for (const workout of workouts) {
        const dateStr = new Date(workout.loggedAt).toISOString().split('T')[0];
        const daySummary = summaryMap.get(dateStr);
        if (daySummary) {
          daySummary.totalCaloriesBurned += workout.caloriesBurned;
        }
      }

      // Compute net calories
      const historyList = Array.from(summaryMap.values()).map(item => {
        // Net Calories Remaining = Base Target - Consumed + Burned (which includes activeCalories)
        item.netCalories = baseTarget - item.totalCaloriesConsumed + item.totalCaloriesBurned;
        return item;
      });

      // 4. Calculate active logging streak
      const allMeals = await prisma.mealLog.findMany({
        where: { userId },
        select: { loggedAt: true },
        orderBy: { loggedAt: 'desc' },
      });

      const allWorkouts = await prisma.workoutLog.findMany({
        where: { userId },
        select: { loggedAt: true },
        orderBy: { loggedAt: 'desc' },
      });

      const logDatesSet = new Set<string>();
      allMeals.forEach(m => logDatesSet.add(new Date(m.loggedAt).toISOString().split('T')[0]));
      allWorkouts.forEach(w => logDatesSet.add(new Date(w.loggedAt).toISOString().split('T')[0]));

      let streak = 0;
      const todayStr = new Date().toISOString().split('T')[0];
      const yesterdayStr = new Date(Date.now() - 86400000).toISOString().split('T')[0];

      let currentCheckDate = new Date();
      let hasLoggedOnCheckDate = logDatesSet.has(todayStr) || logDatesSet.has(yesterdayStr);

      if (hasLoggedOnCheckDate) {
        if (!logDatesSet.has(todayStr) && logDatesSet.has(yesterdayStr)) {
          currentCheckDate.setDate(currentCheckDate.getDate() - 1);
        }

        while (true) {
          const checkStr = currentCheckDate.toISOString().split('T')[0];
          if (logDatesSet.has(checkStr)) {
            streak++;
            currentCheckDate.setDate(currentCheckDate.getDate() - 1);
          } else {
            break;
          }
        }
      }

      // 5. Cache summary records to database
      for (const summary of historyList) {
        try {
          await prisma.dailySummary.upsert({
            where: {
              userId_date: {
                userId,
                date: new Date(summary.date),
              },
            },
            update: {
              totalCaloriesConsumed: summary.totalCaloriesConsumed,
              totalCaloriesBurned: summary.totalCaloriesBurned,
              netCalories: summary.netCalories,
              streakDay: streak,
              steps: summary.steps,
              activeCalories: summary.activeCalories,
            },
            create: {
              userId,
              date: new Date(summary.date),
              totalCaloriesConsumed: summary.totalCaloriesConsumed,
              totalCaloriesBurned: summary.totalCaloriesBurned,
              netCalories: summary.netCalories,
              streakDay: streak,
              steps: summary.steps,
              activeCalories: summary.activeCalories,
            },
          });
        } catch (_) {
          // Fail silently on cache update errors
        }
      }

      reply.send({
        streak,
        history: historyList,
      });
    } catch (error) {
      fastify.log.error(error);
      reply.status(500).send({ message: 'Internal server error fetching summaries' });
    }
  });

  // PATCH /sync (Sync steps and active calories for a specific date)
  fastify.patch('/sync', async (request, reply) => {
    const userId = request.user?.id;
    if (!userId) {
      reply.status(401).send({ message: 'Unauthorized' });
      return;
    }

    const { date, steps, activeCalories } = request.body as any;

    if (!date) {
      reply.status(400).send({ message: 'Missing date parameter' });
      return;
    }

    try {
      const targetDate = new Date(date);
      targetDate.setHours(0, 0, 0, 0);

      const user = await prisma.user.findUnique({
        where: { id: userId },
      });

      if (!user) {
        reply.status(404).send({ message: 'User not found' });
        return;
      }

      const tdee = user.tdee || 2000.0;
      let baseTarget = tdee;
      if (user.fitnessGoal === 'deficit') {
        baseTarget = tdee - 500;
      } else if (user.fitnessGoal === 'surplus') {
        baseTarget = tdee + 300;
      }

      const startOfDay = new Date(targetDate);
      const endOfDay = new Date(targetDate);
      endOfDay.setHours(23, 59, 59, 999);

      const meals = await prisma.mealLog.findMany({
        where: {
          userId,
          loggedAt: { gte: startOfDay, lte: endOfDay },
        },
      });

      const workouts = await prisma.workoutLog.findMany({
        where: {
          userId,
          loggedAt: { gte: startOfDay, lte: endOfDay },
        },
      });

      const totalMealsCals = meals.reduce((sum, m) => sum + m.caloriesConsumed, 0);
      const totalWorkoutsCals = workouts.reduce((sum, w) => sum + w.caloriesBurned, 0);

      const combinedBurned = totalWorkoutsCals + (activeCalories || 0.0);
      const computedNet = baseTarget - totalMealsCals + combinedBurned;

      const updatedSummary = await prisma.dailySummary.upsert({
        where: {
          userId_date: {
            userId,
            date: targetDate,
          },
        },
        update: {
          steps: steps || 0,
          activeCalories: activeCalories || 0.0,
          totalCaloriesBurned: combinedBurned,
          netCalories: computedNet,
        },
        create: {
          userId,
          date: targetDate,
          steps: steps || 0,
          activeCalories: activeCalories || 0.0,
          totalCaloriesConsumed: totalMealsCals,
          totalCaloriesBurned: combinedBurned,
          netCalories: computedNet,
        },
      });

      reply.send(updatedSummary);
    } catch (error) {
      fastify.log.error(error);
      reply.status(500).send({ message: 'Internal server error syncing health data' });
    }
  });
}
