import type { Request, Response, NextFunction } from 'express';
import admin from 'firebase-admin';

// Initialize Firebase Admin once per process using default credentials
// In Cloud Functions, the runtime provides a service account automatically
if (!admin.apps.length) {
  admin.initializeApp();
}

export interface AuthedRequest extends Request {
  user?: {
    uid: string;
    email?: string;
  };
}

export async function authMiddleware(req: AuthedRequest, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : undefined;

  if (!token) {
    return res.status(401).json({ error: 'Missing Authorization header' });
  }

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    req.user = { uid: decoded.uid, email: decoded.email };
    return next();
  } catch (err) {
    console.error('[auth] invalid token', err);
    return res.status(401).json({ error: 'Invalid token' });
  }
}
