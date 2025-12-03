import { Router } from 'express';
import { OpenAI } from 'openai';
import * as functions from 'firebase-functions';
import type { AuthedRequest } from '../middleware/auth';
import {
  canUseTokens,
  recordTokenUsage,
  PLANS,
} from '../services/tokenService';

const router = Router();

const OPENAI_API_KEY =
  process.env.OPENAI_API_KEY || functions.config().openai?.key;

if (!OPENAI_API_KEY) {
  console.warn('[image] OPENAI_API_KEY is not set; image route will fail until configured');
}

const openai = new OpenAI({
  apiKey: OPENAI_API_KEY,
});

router.post('/', async (req: AuthedRequest, res) => {
  if (!req.user) return res.status(401).json({ error: 'Unauthorized' });

  const { prompt } = req.body as { prompt?: string };

  if (!prompt) {
    return res.status(400).json({ error: 'prompt is required' });
  }

  try {
    const imageCost = PLANS.FREE.imageGenerationCost;
    const tokenCheck = await canUseTokens(req.user.uid, imageCost);

    if (!tokenCheck.allowed) {
      return res.status(429).json({
        error: 'Token limit exceeded',
        message: tokenCheck.reason,
        remaining: tokenCheck.remaining,
      });
    }

    const result = await openai.images.generate({
      model: 'dall-e-3',
      prompt,
      n: 1,
      size: '1024x1024',
    });

    const url = result.data?.[0]?.url;
    if (!url) {
      return res.status(500).json({ error: 'Image provider did not return URL' });
    }

    await recordTokenUsage(req.user.uid, imageCost);

    return res.json({ url });
  } catch (err: any) {
    console.error('[image] error', err.response?.data || err.message || err);

    if (err.status === 429) {
      return res.status(429).json({
        error: 'Rate limit exceeded',
        details: 'OpenAI rate limit reached. Please try again later.',
      });
    }

    return res.status(500).json({ error: 'Image provider error', details: err.message });
  }
});

export const imageRouter = router;
