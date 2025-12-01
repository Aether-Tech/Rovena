import admin from 'firebase-admin';

const db = admin.firestore();

// Definição de planos de monetização
// Cálculo baseado em: OpenAI pricing + margem de 70-80%
// Para R$ 100/mês: 4M tokens oferece ~77% de margem
export const PLANS = {
  FREE: {
    name: 'Free',
    monthlyTokenLimit: 10000, // 10k tokens/mês (atração)
    imageGenerationCost: 1000, // custo por imagem
  },
  BASIC: {
    name: 'Basic',
    monthlyTokenLimit: 500000, // 500k tokens/mês (~R$ 29-39/mês)
    imageGenerationCost: 1000,
  },
  PRO: {
    name: 'Pro',
    monthlyTokenLimit: 3000000, // 3M tokens/mês (R$ 100/mês) - margem ~80%
    imageGenerationCost: 1000,
  },
  ENTERPRISE: {
    name: 'Enterprise',
    monthlyTokenLimit: -1, // ilimitado (R$ 299+/mês)
    imageGenerationCost: 1000,
  },
} as const;

export type PlanType = keyof typeof PLANS;

interface UserPlan {
  plan: PlanType;
  stripeCustomerId?: string;
  stripeSubscriptionId?: string;
  subscriptionStatus?: 'active' | 'canceled' | 'past_due' | 'trialing';
}

interface TokenUsage {
  date: string; // YYYY-MM-DD
  tokens: number;
}

/**
 * Busca o plano do usuário do Firestore
 */
export async function getUserPlan(uid: string): Promise<UserPlan> {
  try {
    const userDoc = await db.collection('users').doc(uid).get();
    
    if (!userDoc.exists) {
      // Criar usuário com plano FREE por padrão
      const defaultPlan: UserPlan = { plan: 'FREE' };
      await db.collection('users').doc(uid).set(defaultPlan, { merge: true });
      return defaultPlan;
    }
    
    const data = userDoc.data();
    return {
      plan: (data?.plan as PlanType) || 'FREE',
      stripeCustomerId: data?.stripeCustomerId,
      stripeSubscriptionId: data?.stripeSubscriptionId,
      subscriptionStatus: data?.subscriptionStatus,
    };
  } catch (error) {
    console.error('[tokenService] Error fetching user plan:', error);
    // Em caso de erro, retorna plano FREE
    return { plan: 'FREE' };
  }
}

/**
 * Retorna o limite mensal de tokens baseado no plano
 */
export async function getMonthlyTokenLimit(uid: string): Promise<number> {
  const userPlan = await getUserPlan(uid);
  const planConfig = PLANS[userPlan.plan];
  
  // Verificar se a assinatura está ativa (se tiver Stripe)
  if (userPlan.stripeSubscriptionId && userPlan.subscriptionStatus !== 'active') {
    // Se a assinatura não está ativa, retorna limite do plano FREE
    return PLANS.FREE.monthlyTokenLimit;
  }
  
  return planConfig.monthlyTokenLimit;
}

/**
 * Calcula tokens usados nos últimos 30 dias
 */
export async function getTokensUsedLast30Days(uid: string): Promise<number> {
  try {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const usageRef = db.collection('users').doc(uid).collection('tokenUsage');
    const snapshot = await usageRef
      .where('date', '>=', formatDate(thirtyDaysAgo))
      .get();
    
    let total = 0;
    snapshot.forEach((doc) => {
      const data = doc.data();
      total += data.tokens || 0;
    });
    
    return total;
  } catch (error) {
    console.error('[tokenService] Error calculating usage:', error);
    return 0;
  }
}

/**
 * Verifica se o usuário pode usar tokens
 */
export async function canUseTokens(
  uid: string,
  estimatedTokens: number
): Promise<{ allowed: boolean; reason?: string; remaining?: number }> {
  const limit = await getMonthlyTokenLimit(uid);
  const used = await getTokensUsedLast30Days(uid);
  
  // Plano ilimitado
  if (limit === -1) {
    return { allowed: true, remaining: -1 };
  }
  
  const remaining = limit - used;
  const canUse = remaining >= estimatedTokens;
  
  return {
    allowed: canUse,
    reason: canUse ? undefined : `Token limit exceeded. Used ${used}/${limit} tokens.`,
    remaining: Math.max(0, remaining),
  };
}

/**
 * Registra uso de tokens
 */
export async function recordTokenUsage(
  uid: string,
  tokens: number,
  date: Date = new Date()
): Promise<void> {
  try {
    const dateKey = formatDate(date);
    const usageRef = db
      .collection('users')
      .doc(uid)
      .collection('tokenUsage')
      .doc(dateKey);
    
    await usageRef.set(
      {
        date: dateKey,
        tokens: admin.firestore.FieldValue.increment(tokens),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    
    // Limpar entradas antigas (mais de 30 dias)
    await cleanupOldUsage(uid);
  } catch (error) {
    console.error('[tokenService] Error recording usage:', error);
  }
}

/**
 * Limpa entradas de uso antigas (mais de 30 dias)
 */
async function cleanupOldUsage(uid: string): Promise<void> {
  try {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const cutoffDate = formatDate(thirtyDaysAgo);
    
    const usageRef = db.collection('users').doc(uid).collection('tokenUsage');
    const snapshot = await usageRef.where('date', '<', cutoffDate).get();
    
    const batch = db.batch();
    snapshot.forEach((doc) => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
  } catch (error) {
    console.error('[tokenService] Error cleaning up old usage:', error);
  }
}

/**
 * Formata data para YYYY-MM-DD
 */
function formatDate(date: Date): string {
  return date.toISOString().split('T')[0];
}

/**
 * Estima quantidade de tokens baseado nas mensagens e modelo
 */
export function estimateTokenCount(
  messages: { role: string; content: string }[],
  model: string
): number {
  // Estimativa simples: ~4 caracteres por token em média
  const totalChars = messages.reduce((sum, msg) => sum + (msg.content?.length || 0), 0);
  let estimated = Math.ceil(totalChars / 4);
  
  // Ajuste baseado no modelo (modelos maiores tendem a usar mais tokens)
  if (model.includes('gpt-4')) {
    estimated = Math.ceil(estimated * 1.2); // GPT-4 tende a usar mais tokens
  } else if (model.includes('gpt-3.5')) {
    estimated = Math.ceil(estimated * 0.9); // GPT-3.5 é mais eficiente
  }
  
  // Adicionar overhead para formatação e tokens do sistema
  estimated += messages.length * 3; // ~3 tokens por mensagem de overhead
  
  return estimated;
}

/**
 * Busca ou cria um customer no Stripe pelo email
 * Retorna o customerId do Stripe
 */
export async function getOrCreateStripeCustomer(
  email: string,
  uid: string
): Promise<string | null> {
  try {
    // Verificar se já temos o customerId salvo no Firestore
    const userPlan = await getUserPlan(uid);
    if (userPlan.stripeCustomerId) {
      return userPlan.stripeCustomerId;
    }

    // Se não temos, precisamos buscar/criar no Stripe
    // Esta função deve ser chamada com o cliente Stripe já inicializado
    // Retornamos null para indicar que precisa ser criado externamente
    return null;
  } catch (error) {
    console.error('[tokenService] Error getting Stripe customer:', error);
    return null;
  }
}

/**
 * Atualiza o plano do usuário (útil para webhooks do Stripe)
 */
export async function updateUserPlan(
  uid: string,
  plan: PlanType,
  stripeData?: {
    customerId?: string;
    subscriptionId?: string;
    status?: 'active' | 'canceled' | 'past_due' | 'trialing';
  }
): Promise<void> {
  try {
    const updateData: any = { plan };
    
    if (stripeData) {
      if (stripeData.customerId) updateData.stripeCustomerId = stripeData.customerId;
      if (stripeData.subscriptionId) updateData.stripeSubscriptionId = stripeData.subscriptionId;
      if (stripeData.status) updateData.subscriptionStatus = stripeData.status;
    }
    
    await db.collection('users').doc(uid).set(updateData, { merge: true });
  } catch (error) {
    console.error('[tokenService] Error updating user plan:', error);
    throw error;
  }
}

