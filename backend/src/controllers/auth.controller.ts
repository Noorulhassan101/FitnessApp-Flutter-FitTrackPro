import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import * as jwt from 'jsonwebtoken';

const prisma = new PrismaClient();

const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-jwt-key';
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'super-secret-refresh-key';

function generateTokens(user: { id: string; email: string }) {
  const accessToken = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, {
    expiresIn: '15m',
  });
  
  const refreshToken = jwt.sign({ id: user.id, email: user.email }, REFRESH_SECRET, {
    expiresIn: '7d',
  });

  return { accessToken, refreshToken };
}

export async function authRoutes(fastify: FastifyInstance) {
  // POST /register
  fastify.post('/register', async (request, reply) => {
    const { name, email, password } = request.body as any;

    if (!email || !password) {
      reply.status(400).send({ message: 'Email and password are required' });
      return;
    }

    try {
      const existingUser = await prisma.user.findUnique({ where: { email } });
      if (existingUser) {
        reply.status(409).send({ message: 'User with this email already exists' });
        return;
      }

      const passwordHash = await bcrypt.hash(password, 10);
      const user = await prisma.user.create({
        data: {
          email,
          passwordHash,
          name,
        },
      });

      const { accessToken, refreshToken } = generateTokens(user);

      reply.status(201).send({
        user: { id: user.id, email: user.email, name: user.name },
        accessToken,
        refreshToken,
      });
    } catch (error) {
      fastify.log.error(error);
      reply.status(500).send({ message: 'Internal server error during registration' });
    }
  });

  // POST /login
  fastify.post('/login', async (request, reply) => {
    const { email, password } = request.body as any;

    if (!email || !password) {
      reply.status(400).send({ message: 'Email and password are required' });
      return;
    }

    try {
      const user = await prisma.user.findUnique({ where: { email } });
      if (!user) {
        reply.status(401).send({ message: 'Invalid email or password' });
        return;
      }

      const passwordMatch = await bcrypt.compare(password, user.passwordHash);
      if (!passwordMatch) {
        reply.status(401).send({ message: 'Invalid email or password' });
        return;
      }

      const { accessToken, refreshToken } = generateTokens(user);

      reply.send({
        user: { 
          id: user.id, 
          email: user.email, 
          name: user.name,
          age: user.age,
          gender: user.gender,
          heightCm: user.heightCm,
          weightKg: user.weightKg,
          fitnessGoal: user.fitnessGoal,
          activityLevel: user.activityLevel,
          bmr: user.bmr,
          tdee: user.tdee,
          unitPreference: user.unitPreference,
        },
        accessToken,
        refreshToken,
      });
    } catch (error) {
      fastify.log.error(error);
      reply.status(500).send({ message: 'Internal server error during login' });
    }
  });

  // POST /refresh
  fastify.post('/refresh', async (request, reply) => {
    const { refreshToken } = request.body as any;

    if (!refreshToken) {
      reply.status(400).send({ message: 'Refresh token is required' });
      return;
    }

    try {
      const decoded = jwt.verify(refreshToken, REFRESH_SECRET) as {
        id: string;
        email: string;
      };

      const user = await prisma.user.findUnique({ where: { id: decoded.id } });
      if (!user) {
        reply.status(401).send({ message: 'User session no longer exists' });
        return;
      }

      const tokens = generateTokens(user);
      reply.send(tokens);
    } catch (error) {
      reply.status(401).send({ message: 'Invalid or expired refresh token' });
    }
  });

  // POST /google
  fastify.post('/google', async (request, reply) => {
    const { idToken, email, name } = request.body as any;

    if (!email) {
      reply.status(400).send({ message: 'Google Sign-In email is required' });
      return;
    }

    try {
      let verifiedEmail = email;
      let verifiedName = name;

      // Verify Google idToken if provided
      if (idToken) {
        try {
          const googleVerifyRes = await fetch(
            `https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`
          );
          if (googleVerifyRes.status === 200) {
            const tokenData = await googleVerifyRes.json() as any;
            verifiedEmail = tokenData.email;
            verifiedName = tokenData.name || verifiedName;
          }
        } catch (verifyErr) {
          fastify.log.warn(verifyErr, 'Google ID token verification failed, falling back to client parameters in development');
        }
      }

      // Check if user exists or register them
      let user = await prisma.user.findUnique({ where: { email: verifiedEmail } });
      if (!user) {
        // Create random password hash for OAuth users
        const passwordHash = await bcrypt.hash(Math.random().toString(36), 10);
        user = await prisma.user.create({
          data: {
            email: verifiedEmail,
            passwordHash,
            name: verifiedName,
          },
        });
      }

      const { accessToken, refreshToken } = generateTokens(user);

      reply.send({
        user: { 
          id: user.id, 
          email: user.email, 
          name: user.name,
          age: user.age,
          gender: user.gender,
          heightCm: user.heightCm,
          weightKg: user.weightKg,
          fitnessGoal: user.fitnessGoal,
          activityLevel: user.activityLevel,
          bmr: user.bmr,
          tdee: user.tdee,
          unitPreference: user.unitPreference,
        },
        accessToken,
        refreshToken,
      });
    } catch (error) {
      fastify.log.error(error);
      reply.status(500).send({ message: 'Internal server error during Google Sign-In' });
    }
  });
}
