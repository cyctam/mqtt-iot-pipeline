import mqtt from 'mqtt';
import { addMessage } from './store';
import { logger } from './logger';

export function startMqttSubscriber() {
  const url = process.env.MQTT_URL || 'mqtt://localhost:1883';
  const topic = process.env.MQTT_TOPIC || 'broadcast';

  logger.info(`Connecting to MQTT broker url=${url}`);

  const client = mqtt.connect(url, {
    clientId: `api-server-${Math.random().toString(16).slice(2, 8)}`,
    reconnectPeriod: 3000,
  });

  client.on('connect', () => {
    logger.info('MQTT connection established');
    client.subscribe(topic, { qos: 0 }, (err) => {
      if (err) {
        logger.error(`Subscribe failed topic=${topic} error=${err.message}`);
      } else {
        logger.info(`Subscribed topic=${topic} qos=0`);
      }
    });
  });

  client.on('message', (t, buf, packet) => {
    const payload = buf.toString();
    const now = Date.now();

    let latencyMs = 0;
    let parsed: any = null;
    try {
      parsed = JSON.parse(payload);
      if (parsed.sentAt) latencyMs = now - parsed.sentAt;
    } catch {
      // payload is not JSON
    }

    const record = addMessage({
      topic: t,
      payload,
      qos: packet.qos,
      latencyMs,
      status: 'DELIVERED',
    });

    const seq = String(record.seq).padStart(4, '0');
    const bytes = buf.length;
    const msg = parsed?.data?.message || payload;
    const payloadSeq = parsed?.data?.seq ?? record.seq;

    logger.mqtt(
      `Packet=${seq} | Topic=${t} | Seq=${payloadSeq} | QoS=${packet.qos} | Latency=${latencyMs}ms | Bytes=${bytes} | Payload="${msg}" | Status=DELIVERED`
    );
  });

  client.on('error', (err) => {
    logger.error(`MQTT error=${err.message}`);
  });

  client.on('reconnect', () => {
    logger.warn('MQTT reconnecting');
  });

  client.on('close', () => {
    logger.warn('MQTT connection closed');
  });

  return client;
}