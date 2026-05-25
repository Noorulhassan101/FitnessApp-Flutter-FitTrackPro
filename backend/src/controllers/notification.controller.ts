import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { verifyJWT } from '../middlewares/auth.middleware';

const prisma = new PrismaClient();

export async function notificationRoutes(fastify: FastifyInstance) {
  // Apply JWT verification middleware to all routes in this controller
  fastify.addHook('preHandler', verifyJWT);

  // GET / (Get all notification logs for the user)
  fastify.get('/', async (request, reply) => {
    const userId = request.user?.id;
    if (!userId) {
      reply.status(401).send({ message: 'Unauthorized' });
      return;
    }

    try {
      const logs = await prisma.notification.findMany({
        where: { userId },
        orderBy: { scheduledAt: 'desc' },
      });

      reply.send(logs);
    } catch (error) {
      fastify.log.error(error);
      reply.status(500).send({ message: 'Internal server error fetching notifications' });
    }
  });

  // PATCH /:id/read (Mark a notification as read)
  fastify.patch('/:id/read', async (request, reply) => {
    const userId = request.user?.id;
    const { id } = request.params as any;

    if (!userId) {
      reply.status(401).send({ message: 'Unauthorized' });
      return;
    }

    try {
      const notification = await prisma.notification.findFirst({
        where: { id, userId },
      });

      if (!notification) {
        reply.status(404).send({ message: 'Notification log not found' });
        return;
      }

      const updated = await prisma.notification.update({
        where: { id },
        data: { isRead: true, sentAt: new Date() },
      });

      reply.send(updated);
    } catch (error) {
      fastify.log.error(error);
      reply.status(500).send({ message: 'Internal server error updating notification' });
    }
  });

  // POST /schedule (Log a scheduled reminder)
  fastify.post('/schedule', async (request, reply) => {
    const userId = request.user?.id;
    if (!userId) {
      reply.status(401).send({ message: 'Unauthorized' });
      return;
    }

    const { type, scheduledAt, message } = request.body as any;

    if (!type || !scheduledAt || !message) {
      reply.status(400).send({ message: 'Missing type, scheduledAt, or message' });
      return;
    }

    try {
      const created = await prisma.notification.create({
        data: {
          userId,
          type,
          scheduledAt: new Date(scheduledAt),
          message,
        },
      });

      reply.status(201).send(created);
    } catch (error) {
      fastify.log.error(error);
      reply.status(500).send({ message: 'Internal server error scheduling notification' });
    }
  });
}
