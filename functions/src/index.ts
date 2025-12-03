import * as functions from 'firebase-functions';
import express from 'express';
import cors from 'cors';
import { authMiddleware } from './middleware/auth';
import { chatRouter } from './routes/chat';
import { imageRouter } from './routes/image';
import { tokensRouter } from './routes/tokens';
import { stripeWebhookRouter } from './routes/stripe-webhook';

const app = express();

// Allow JSON bodies and CORS
app.use(cors({ origin: true }));
app.use(express.json());

// Auth using Firebase ID token (same lógica que backend)
app.use(authMiddleware);

// Main API routes
app.use('/chat', chatRouter);
app.use('/image', imageRouter);
app.use('/tokens', tokensRouter);

// Stripe webhook (sem auth; Stripe não manda token Firebase)
app.use('/stripe', stripeWebhookRouter);

export const api = functions.https.onRequest(app);
