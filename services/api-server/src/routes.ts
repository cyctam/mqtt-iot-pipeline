import { Router, Request, Response } from 'express';
import {
  getMessages,
  getMessageById,
  updateMessage,
  deleteMessage,
} from './store';

export function createRoutes(publishFn: (payload: string) => void): Router {
  const router = Router();

  router.get('/messages', (_req: Request, res: Response) => {
    res.json({
      success: true,
      count: getMessages().length,
      data: getMessages(),
    });
  });

  router.get('/messages/:id', (req: Request, res: Response) => {
    const msg = getMessageById(req.params.id);
    if (!msg) {
      res.status(404).json({ success: false, error: 'Not found' });
      return;
    }
    res.json({ success: true, data: msg });
  });

  router.post('/publish', (req: Request, res: Response) => {
    const { message } = req.body;
    if (!message) {
      res.status(400).json({ success: false, error: 'message is required' });
      return;
    }
    publishFn(JSON.stringify({ message, sentAt: Date.now() }));
    res.status(201).json({ success: true, message: 'Published to MQTT' });
  });

  router.put('/messages/:id', (req: Request, res: Response) => {
    const updated = updateMessage(req.params.id, req.body);
    if (!updated) {
      res.status(404).json({ success: false, error: 'Not found' });
      return;
    }
    res.json({ success: true, data: updated });
  });

  router.delete('/messages/:id', (req: Request, res: Response) => {
    const ok = deleteMessage(req.params.id);
    if (!ok) {
      res.status(404).json({ success: false, error: 'Not found' });
      return;
    }
    res.json({ success: true, message: 'Deleted' });
  });

  router.get('/health', (_req: Request, res: Response) => {
    res.json({ status: 'ok', uptime: process.uptime() });
  });

  return router;
}