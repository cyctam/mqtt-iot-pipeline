import { Request, Response, NextFunction } from 'express';
import { logger, formatMethod } from './logger';

export function apiLogger(req: Request, res: Response, next: NextFunction) {
  const start = Date.now();

  const originalSend = res.send.bind(res);
  res.send = (body: any) => {
    const duration = Date.now() - start;
    const method = formatMethod(req.method);
    const path = req.originalUrl;
    const status = res.statusCode;

    logger.api(`${method} ${path} status=${status} duration=${duration}ms`);
    return originalSend(body);
  };

  next();
}