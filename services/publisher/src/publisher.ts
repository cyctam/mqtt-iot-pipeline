import { Context } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import * as mqtt from 'mqtt';

const host = process.env.MQ_HOST || 'mqtt://localhost:1883';
const topic = process.env.MQ_TOPIC || 'broadcast';

// Module-level client — sekali connect, dipakai terus
let client: mqtt.MqttClient | null = null;

function getClient(): Promise<mqtt.MqttClient> {
  return new Promise((resolve, reject) => {
    if (client && client.connected) {
      return resolve(client);
    }

    client = mqtt.connect(host, {
      username: process.env.MQ_USERNAME || undefined,
      password: process.env.MQ_PASSWORD || undefined,
      protocol: host.startsWith('mqtts') ? 'mqtts' : 'mqtt',
      clientId: `publisher_${uuidv4()}`,
    });

    const timeout = setTimeout(() => {
      reject(new Error('MQTT connect timeout'));
    }, 10000);

    client.once('connect', () => {
      clearTimeout(timeout);
      resolve(client!);
    });

    client.once('error', (err) => {
      clearTimeout(timeout);
      reject(err);
    });
  });
}

export async function handler(event: any, _context: Context): Promise<any> {
  const message = JSON.stringify({
    id: uuidv4(),
    time: Date.now(),
    sentAt: Date.now(),
    data: event,
  });

  const c = await getClient();

  await new Promise<void>((resolve, reject) => {
    c.publish(topic, message, { qos: 0 }, (err) => {
      if (err) return reject(err);
      resolve();
    });
  });

  return {
    status: 'success',
    message: `published on ${topic}`,
  };
}