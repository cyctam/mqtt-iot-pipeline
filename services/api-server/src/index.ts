import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import http from 'http';
import mqtt from 'mqtt';
import { WebSocketServer } from 'ws';
import { startMqttSubscriber } from './mqtt';
import { createRoutes } from './routes';
import { getMessages } from './store';
import { apiLogger } from './apiLogger';
import { logger } from './logger';

const PORT = Number(process.env.PORT) || 4000;
const MQTT_URL = process.env.MQTT_URL || 'mqtt://localhost:1883';
const MQTT_TOPIC = process.env.MQTT_TOPIC || 'broadcast';

const app = express();
app.use(cors());
app.use(express.json());
app.use(apiLogger);

const publisherClient = mqtt.connect(MQTT_URL, {
  clientId: `api-pub-${Math.random().toString(16).slice(2, 8)}`,
});

publisherClient.on('connect', () => {
  logger.info('Publisher MQTT connection established');
});

publisherClient.on('error', (err) => {
  logger.error(`Publisher MQTT error=${err.message}`);
});

const publishFn = (payload: string) => {
  publisherClient.publish(MQTT_TOPIC, payload, { qos: 0 });
};

app.use('/api', createRoutes(publishFn));

const subscriber = startMqttSubscriber();

const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

wss.on('connection', () => {
  logger.info('WebSocket client connected path=/ws');
});

server.listen(PORT, () => {
  logger.startup('  Service    : mqtt-realtime-pubsub/api-server');
  logger.startup(`  REST API   : http://localhost:${PORT}/api`);
  logger.startup(`  WebSocket  : ws://localhost:${PORT}/ws`);
  logger.startup(`  MQTT Broker: ${MQTT_URL}`);
  logger.startup(`  Topic      : ${MQTT_TOPIC}`);
  logger.info('Service started');
});

process.on('SIGINT', () => {
  logger.warn('Shutdown signal received');
  subscriber.end();
  publisherClient.end();
  server.close(() => {
    logger.info('Service stopped');
    process.exit(0);
  });
});