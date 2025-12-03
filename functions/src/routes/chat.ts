import { Router } from 'express';
import { OpenAI } from 'openai';
import * as functions from 'firebase-functions';
import type { AuthedRequest } from '../middleware/auth';
import {
  canUseTokens,
  recordTokenUsage,
  estimateTokenCount,
} from '../services/tokenService';

const router = Router();

const OPENAI_API_KEY =
  process.env.OPENAI_API_KEY || functions.config().openai?.key;

if (!OPENAI_API_KEY) {
  console.warn('[chat] OPENAI_API_KEY is not set; chat route will fail until configured');
}

const openai = new OpenAI({
  apiKey: OPENAI_API_KEY,
});

router.post('/', async (req: AuthedRequest, res) => {
  if (!req.user) return res.status(401).json({ error: 'Unauthorized' });

  const { model, messages } = req.body as {
    model?: string;
    messages?: { role: string; content: string }[];
  };

  if (!model || !messages || !Array.isArray(messages)) {
    return res.status(400).json({ error: 'model and messages are required' });
  }

  try {
    const estimatedTokens = estimateTokenCount(messages, model);

    const tokenCheck = await canUseTokens(req.user.uid, estimatedTokens);

    if (!tokenCheck.allowed) {
      return res.status(429).json({
        error: 'Token limit exceeded',
        message: tokenCheck.reason,
        remaining: tokenCheck.remaining,
      });
    }

    const completion = await openai.chat.completions.create({
      model,
      messages: messages.map((m) => ({ role: m.role as any, content: m.content })),
    });

    const actualTokens = completion.usage?.total_tokens || estimatedTokens;
    await recordTokenUsage(req.user.uid, actualTokens);

    return res.json(completion);
  } catch (err: any) {
    console.error('[chat] error', err.response?.data || err.message || err);

    if (err.status === 429) {
      return res.status(429).json({
        error: 'Rate limit exceeded',
        details: 'OpenAI rate limit reached. Please try again later.',
      });
    }

    return res.status(500).json({ error: 'Chat provider error', details: err.message });
  }
});

export const chatRouter = router;
