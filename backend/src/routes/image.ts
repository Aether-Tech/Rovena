import { Router } from 'express';
import { OpenAI } from 'openai';
import type { AuthedRequest } from '../middleware/auth';
import {
  canUseTokens,
  recordTokenUsage,
  PLANS,
} from '../services/tokenService';

const router = Router();

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

router.post('/', async (req: AuthedRequest, res) => {
  if (!req.user) return res.status(401).json({ error: 'Unauthorized' });

  const { prompt } = req.body as { prompt?: string };

  if (!prompt) {
    return res.status(400).json({ error: 'prompt is required' });
  }

  try {
    // VERIFICAÇÃO DE SEGURANÇA: Verificar se usuário pode gerar imagem
    // Geração de imagem tem custo fixo (definido no plano)
    const imageCost = PLANS.FREE.imageGenerationCost; // Usa custo padrão
    const tokenCheck = await canUseTokens(req.user.uid, imageCost);
    
    if (!tokenCheck.allowed) {
      return res.status(429).json({
        error: 'Token limit exceeded',
        message: tokenCheck.reason,
        remaining: tokenCheck.remaining,
      });
    }

    // Fazer requisição para OpenAI
    const result = await openai.images.generate({
      model: 'dall-e-3',
      prompt,
      n: 1,
      size: '1024x1024',
    });

    const url = result.data[0]?.url;
    if (!url) {
      return res.status(500).json({ error: 'Image provider did not return URL' });
    }

    // Registrar uso de tokens para geração de imagem
    await recordTokenUsage(req.user.uid, imageCost);

    return res.json({ url });
  } catch (err: any) {
    console.error('[image] error', err.response?.data || err.message || err);
    
    // Se for erro de limite da OpenAI, retornar erro apropriado
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
