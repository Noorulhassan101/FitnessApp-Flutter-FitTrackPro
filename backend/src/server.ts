import fastify from 'fastify';
import cors from '@fastify/cors';
import { PrismaClient } from '@prisma/client';
import * as dotenv from 'dotenv';
import { authRoutes } from './controllers/auth.controller';
import { userRoutes } from './controllers/user.controller';
import { workoutRoutes } from './controllers/workout.controller';
import { mealRoutes } from './controllers/meal.controller';
import { summaryRoutes } from './controllers/summary.controller';

dotenv.config();

const server = fastify({ logger: true });
const prisma = new PrismaClient();

const PORT = parseInt(process.env.PORT || '5005', 10);

async function start() {
  try {
    // Register CORS
    await server.register(cors, {
      origin: '*', // Allow all origins for local mobile development
    });

    // Register Routes
    await server.register(authRoutes, { prefix: '/api/v1/auth' });
    await server.register(userRoutes, { prefix: '/api/v1/user' });
    await server.register(workoutRoutes, { prefix: '/api/v1/workouts' });
    await server.register(mealRoutes, { prefix: '/api/v1/meals' });
    await server.register(summaryRoutes, { prefix: '/api/v1/summary' });

    // Health route
    server.get('/health', async (_request, reply) => {
      try {
        // Test database connection
        await prisma.$queryRaw`SELECT 1`;
        return {
          status: 'ok',
          database: 'connected',
          timestamp: new Date().toISOString(),
        };
      } catch (dbError) {
        server.log.error(dbError, 'Database connection failed');
        reply.status(500);
        return {
          status: 'error',
          database: 'disconnected',
          timestamp: new Date().toISOString(),
        };
      }
    });

    // Start listening
    await server.listen({ port: PORT, host: '0.0.0.0' });
    console.log(`🚀 Server listening on http://localhost:${PORT}`);
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
}

start();
