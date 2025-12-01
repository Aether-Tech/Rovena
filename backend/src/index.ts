import express from 'express';
import cors from 'cors';
import "dotenv/config";

import { authMiddleware } from './middleware/auth';
import { chatRouter } from './routes/chat';
import { imageRouter } from './routes/image';
import { tokensRouter } from './routes/tokens';
import { stripeWebhookRouter } from './routes/stripe-webhook';

const app = express();
const port = process.env.PORT || 8787;

app.use(cors());
app.use(express.json({ limit: '2mb' }));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'rovena-backend' });
});

// Stripe webhook (não requer autenticação Firebase, mas deve verificar assinatura do Stripe)
app.use('/api/stripe', stripeWebhookRouter);

// All API routes require Firebase-authenticated user
app.use('/api', authMiddleware);
app.use('/api/chat', chatRouter);
app.use('/api/image', imageRouter);
app.use('/api/tokens', tokensRouter);

app.listen(port, () => {
  console.log(`[rovena-backend] listening on port ${port}`);
});
