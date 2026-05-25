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

      // 2. Fetch meals and workouts logged in the last 7 days
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
      sevenDaysAgo.setHours(0, 0, 0, 0);

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
      }>();

      // Initialize summary map for the last 7 days (including today)
      for (let i = 6; i >= 0; i--) {
        const d = new Date();
        d.setDate(d.getDate() - i);
        const dateStr = d.toISOString().split('T')[0];
        summaryMap.set(dateStr, {
          date: dateStr,
          totalCaloriesConsumed: 0,
          totalCaloriesBurned: 0,
          netCalories: 0,
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
        // Net Calories Remaining = Base Target - Consumed + Burned
        item.netCalories = baseTarget - item.totalCaloriesConsumed + item.totalCaloriesBurned;
        return item;
      });

      // 4. Calculate active logging streak
      // Query ALL meals and workouts for the user ordered by date descending
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

      // Gather all logging dates as sorted set
      const logDatesSet = new Set<string>();
      allMeals.forEach(m => logDatesSet.add(new Date(m.loggedAt).toISOString().split('T')[0]));
      allWorkouts.forEach(w => logDatesSet.add(new Date(w.loggedAt).toISOString().split('T')[0]));

      let streak = 0;
      const todayStr = new Date().toISOString().split('T')[0];
      const yesterdayStr = new Date(Date.now() - 86400000).toISOString().split('T')[0];

      // Check if user has logged anything today or yesterday to start counting
      let currentCheckDate = new Date();
      let hasLoggedOnCheckDate = logDatesSet.has(todayStr) || logDatesSet.has(yesterdayStr);

      if (hasLoggedOnCheckDate) {
        // If they logged yesterday but not today, start counting from yesterday
        if (!logDatesSet.has(todayStr) && logDatesSet.has(yesterdayStr)) {
          currentCheckDate.setDate(currentCheckDate.getDate() - 1);
        }

        while (true) {
          const checkStr = currentCheckDate.toISOString().split('T')[0];
          if (logDatesSet.has(checkStr)) {
            streak++;
            currentCheckDate.setDate(currentCheckDate.getDate() - 1); // Go back one day
          } else {
            break;
          }
        }
      }

      // 5. Update/Sync the computed summary into Prisma database for completeness (optional sync log caching)
      // For each day in the last 7 days, let's write to DailySummary
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
            },
            create: {
              userId,
              date: new Date(summary.date),
              totalCaloriesConsumed: summary.totalCaloriesConsumed,
              totalCaloriesBurned: summary.totalCaloriesBurned,
              netCalories: summary.netCalories,
              streakDay: streak,
            },
          });
        } catch (_) {
          // Fail silently on cache update errors to prevent request crashes
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
}
