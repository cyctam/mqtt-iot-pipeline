import fs from 'fs';
import path from 'path';

export interface MessageRecord {
  id: string;
  seq: number;
  topic: string;
  payload: string;
  qos: number;
  latencyMs: number;
  status: 'DELIVERED' | 'PENDING' | 'FAILED';
  receivedAt: string;
}

const LOG_FILE = path.resolve(process.env.LOG_FILE || 'logs/messages.csv');

fs.mkdirSync(path.dirname(LOG_FILE), { recursive: true });

if (!fs.existsSync(LOG_FILE)) {
  fs.writeFileSync(
    LOG_FILE,
    'id,seq,topic,payload,qos,latencyMs,status,receivedAt\n'
  );
}

const messages: MessageRecord[] = [];
let seqCounter = 0;

export function addMessage(
  msg: Omit<MessageRecord, 'id' | 'seq' | 'receivedAt'>
): MessageRecord {
  const record: MessageRecord = {
    id: `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`,
    seq: ++seqCounter,
    receivedAt: new Date().toISOString(),
    ...msg,
  };
  messages.push(record);

  const line = [
    record.id,
    record.seq,
    record.topic,
    `"${record.payload.replace(/"/g, '""')}"`,
    record.qos,
    record.latencyMs,
    record.status,
    record.receivedAt,
  ].join(',');
  fs.appendFileSync(LOG_FILE, line + '\n');

  return record;
}

export function getMessages(): MessageRecord[] {
  return messages;
}

export function getMessageById(id: string): MessageRecord | undefined {
  return messages.find((m) => m.id === id);
}

export function updateMessage(
  id: string,
  patch: Partial<Pick<MessageRecord, 'payload' | 'status'>>
): MessageRecord | undefined {
  const msg = messages.find((m) => m.id === id);
  if (!msg) return undefined;
  Object.assign(msg, patch);
  return msg;
}

export function deleteMessage(id: string): boolean {
  const idx = messages.findIndex((m) => m.id === id);
  if (idx === -1) return false;
  messages.splice(idx, 1);
  return true;
}