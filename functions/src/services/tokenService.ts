import admin from 'firebase-admin';

const db = admin.firestore();

export const PLANS = {
  FREE: {
    name: 'Free',
    monthlyTokenLimit: 10000,
    imageGenerationCost: 1000,
  },
  BASIC: {
    name: 'Basic',
    monthlyTokenLimit: 500000,
    imageGenerationCost: 1000,
  },
  PRO: {
    name: 'Pro',
    monthlyTokenLimit: 3000000,
    imageGenerationCost: 1000,
  },
  ENTERPRISE: {
    name: 'Enterprise',
    monthlyTokenLimit: -1,
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
  date: string;
  tokens: number;
}

export async function getUserPlan(uid: string): Promise<UserPlan> {
  try {
    const userDoc = await db.collection('users').doc(uid).get();

    if (!userDoc.exists) {
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
    return { plan: 'FREE' };
  }
}

export async function getMonthlyTokenLimit(uid: string): Promise<number> {
  const userPlan = await getUserPlan(uid);
  const planConfig = PLANS[userPlan.plan];

  if (userPlan.stripeSubscriptionId && userPlan.subscriptionStatus !== 'active') {
    return PLANS.FREE.monthlyTokenLimit;
  }

  return planConfig.monthlyTokenLimit;
}

export async function getTokensUsedLast30Days(uid: string): Promise<number> {
  try {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const usageRef = db.collection('users').doc(uid).collection('tokenUsage');
    const snapshot = await usageRef.where('date', '>=', formatDate(thirtyDaysAgo)).get();

    let total = 0;
    snapshot.forEach((doc) => {
      const data = doc.data() as TokenUsage;
      total += data.tokens || 0;
    });

    return total;
  } catch (error) {
    console.error('[tokenService] Error calculating usage:', error);
    return 0;
  }
}

export async function canUseTokens(
  uid: string,
  estimatedTokens: number
): Promise<{ allowed: boolean; reason?: string; remaining?: number }> {
  const limit = await getMonthlyTokenLimit(uid);
  const used = await getTokensUsedLast30Days(uid);

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

    await cleanupOldUsage(uid);
  } catch (error) {
    console.error('[tokenService] Error recording usage:', error);
  }
}

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

function formatDate(date: Date): string {
  return date.toISOString().split('T')[0];
}

export function estimateTokenCount(
  messages: { role: string; content: string }[],
  model: string
): number {
  const totalChars = messages.reduce((sum, msg) => sum + (msg.content?.length || 0), 0);
  let estimated = Math.ceil(totalChars / 4);

  if (model.includes('gpt-4')) {
    estimated = Math.ceil(estimated * 1.2);
  } else if (model.includes('gpt-3.5')) {
    estimated = Math.ceil(estimated * 0.9);
  }

  estimated += messages.length * 3;

  return estimated;
}

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
    const data: any = { plan };
    if (stripeData) {
      if (stripeData.customerId) data.stripeCustomerId = stripeData.customerId;
      if (stripeData.subscriptionId) data.stripeSubscriptionId = stripeData.subscriptionId;
      if (stripeData.status) data.subscriptionStatus = stripeData.status;
    }

    await db.collection('users').doc(uid).set(data, { merge: true });
  } catch (error) {
    console.error('[tokenService] Error updating user plan:', error);
  }
}
