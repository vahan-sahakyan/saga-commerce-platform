import fastify, { FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import { config } from './config/config';
import { EventConsumer } from './events/consumer';
import pino from 'pino';

// use fastify's built-in logger option for compatibility
const logger = true;


let consumer: EventConsumer;
let app: FastifyInstance | undefined;

async function buildApp(): Promise<FastifyInstance> {
  const app = fastify({
    logger,
  });

  // register plugins
  await app.register(cors);

  // health check endpoint
  app.get('/health', async () => {
    return {
      status: 'healthy',
      service: config.serviceName,
    };
  });

  // root endpoint
  app.get('/', async () => {
    return {
      service: config.serviceName,
      version: '1.0.0',
    };
  });

  return app;
}

async function start(): Promise<void> {
  try {
    // log using app after it's created

    // build fastify app
    app = await buildApp();

    // start event consumer
    consumer = new EventConsumer();
    await consumer.start();

    // start HTTP server
    await app.listen({
      port: config.port,
      host: '0.0.0.0',
    });

    app.log.info(`notification service started on port ${config.port}`);
  } catch (error) {
    if (app && typeof app.log?.error === 'function') {
      app.log.error(error, 'failed to start notification service');
    } else {
      // fallback
      console.error(error, 'failed to start notification service');
    }
    process.exit(1);
  }
}

async function shutdown(): Promise<void> {
  if (app && typeof app.log?.info === 'function') {
    app.log.info('shutting down notification service...');
  } else {
    console.info('shutting down notification service...');
  }

  if (consumer) {
    await consumer.stop();
  }

  if (app && typeof app.log?.info === 'function') {
    app.log.info('notification service stopped');
  } else {
    console.info('notification service stopped');
  }
  process.exit(0);
}

// handle shutdown signals
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

// start the service
start();
