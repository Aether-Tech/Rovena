import { Router } from 'express';
import { OpenAI } from 'openai';
import type { AuthedRequest } from '../middleware/auth';
import {
  canUseTokens,
  recordTokenUsage,
  estimateTokenCount,
} from '../services/tokenService';

const router = Router();

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
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
    // Estimar tokens antes de processar
    const estimatedTokens = estimateTokenCount(messages, model);
    
    // VERIFICAÇÃO DE SEGURANÇA: Verificar se usuário pode usar tokens
    const tokenCheck = await canUseTokens(req.user.uid, estimatedTokens);
    
    if (!tokenCheck.allowed) {
      return res.status(429).json({
        error: 'Token limit exceeded',
        message: tokenCheck.reason,
        remaining: tokenCheck.remaining,
      });
    }

    // Fazer requisição para OpenAI
    const completion = await openai.chat.completions.create({
      model,
      messages: messages.map(m => ({ role: m.role as any, content: m.content })),
    });

    // Registrar uso real de tokens (do response da OpenAI)
    const actualTokens = completion.usage?.total_tokens || estimatedTokens;
    await recordTokenUsage(req.user.uid, actualTokens);

    return res.json(completion);
  } catch (err: any) {
    console.error('[chat] error', err.response?.data || err.message || err);
    
    // Se for erro de limite da OpenAI, retornar erro apropriado
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
