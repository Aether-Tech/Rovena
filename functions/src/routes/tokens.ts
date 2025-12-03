import { Router } from 'express';
import type { AuthedRequest } from '../middleware/auth';
import type { Response } from 'express';
import Stripe from 'stripe';
import * as functions from 'firebase-functions';
import {
  getMonthlyTokenLimit,
  getTokensUsedLast30Days,
  getUserPlan,
  updateUserPlan,
} from '../services/tokenService';

const router = Router();

export const ROVENA_PLUS_PRODUCT_ID = 'prod_TV9GzjLJOU202c';

const STRIPE_SECRET_KEY =
  process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret;

const stripe = STRIPE_SECRET_KEY
  ? new Stripe(STRIPE_SECRET_KEY, {
      apiVersion: '2024-06-20',
    })
  : null;

router.get('/status', async (req: AuthedRequest, res: Response) => {
  if (!req.user) return res.status(401).json({ error: 'Unauthorized' });

  try {
    const monthlyLimit = await getMonthlyTokenLimit(req.user.uid);
    const tokensUsedLast30Days = await getTokensUsedLast30Days(req.user.uid);
    const userPlan = await getUserPlan(req.user.uid);

    if (req.user.email && stripe && STRIPE_SECRET_KEY) {
      try {
        let customerId = userPlan.stripeCustomerId;
        if (!customerId) {
          customerId = await getOrCreateStripeCustomerByEmail(req.user.email, req.user.uid);
        }

        const subscriptions = await stripe.subscriptions.list({
          customer: customerId,
          status: 'all',
          limit: 10,
        });

        console.log(`[tokens] Found ${subscriptions.data.length} subscriptions for ${req.user.email}`);

        const activeSubscription = subscriptions.data.find(
          (sub: Stripe.Subscription) => sub.status === 'active' || sub.status === 'trialing'
        );

        if (activeSubscription) {
          const rovenaItem = activeSubscription.items.data.find(
            (item: Stripe.SubscriptionItem) => item.price.product === ROVENA_PLUS_PRODUCT_ID
          );

          if (rovenaItem) {
            const priceId = rovenaItem.price.id;
            const priceAmount = rovenaItem.price.unit_amount;
            const priceNickname = rovenaItem.price.nickname || '';

            let plan: 'BASIC' | 'PRO' | 'ENTERPRISE' = 'BASIC';

            if (priceAmount) {
              const amountInReais = priceAmount / 100;
              if (amountInReais >= 299) {
                plan = 'ENTERPRISE';
              } else if (amountInReais >= 90) {
                plan = 'PRO';
              } else if (amountInReais >= 25) {
                plan = 'BASIC';
              }
            }

            if (priceId) {
              const priceIdLower = priceId.toLowerCase();
              if (priceIdLower.includes('enterprise')) {
                plan = 'ENTERPRISE';
              } else if (priceIdLower.includes('pro') || priceIdLower.includes('100')) {
                plan = 'PRO';
              } else if (
                priceIdLower.includes('basic') ||
                priceIdLower.includes('29') ||
                priceIdLower.includes('39')
              ) {
                plan = 'BASIC';
              }
            }

            if (priceNickname) {
              const nicknameLower = priceNickname.toLowerCase();
              if (nicknameLower.includes('enterprise')) {
                plan = 'ENTERPRISE';
              } else if (nicknameLower.includes('pro')) {
                plan = 'PRO';
              } else if (nicknameLower.includes('basic')) {
                plan = 'BASIC';
              }
            }

            await updateUserPlan(req.user.uid, plan, {
              customerId: customerId,
              subscriptionId: activeSubscription.id,
              status: activeSubscription.status as 'active' | 'canceled' | 'past_due' | 'trialing',
            });

            const updatedLimit = await getMonthlyTokenLimit(req.user.uid);
            return res.json({
              monthlyLimit: updatedLimit,
              tokensUsedLast30Days,
              plan: plan,
              remaining:
                updatedLimit === -1 ? -1 : Math.max(0, updatedLimit - tokensUsedLast30Days),
              subscriptionStatus: activeSubscription.status,
              stripeSubscriptionId: activeSubscription.id,
              stripeCustomerId: customerId,
              syncedFromStripe: true,
            });
          }
        }
      } catch (stripeError: any) {
        console.error('[tokens] Error syncing with Stripe:', stripeError);
      }
    }

    const finalPlan = userPlan.plan;
    const finalLimit = await getMonthlyTokenLimit(req.user.uid);

    return res.json({
      monthlyLimit: finalLimit,
      tokensUsedLast30Days,
      plan: finalPlan,
      remaining: finalLimit === -1 ? -1 : Math.max(0, finalLimit - tokensUsedLast30Days),
      subscriptionStatus: userPlan.subscriptionStatus,
      stripeSubscriptionId: userPlan.stripeSubscriptionId,
      stripeCustomerId: userPlan.stripeCustomerId,
    });
  } catch (err: any) {
    console.error('[tokens] error', err);
    return res.status(500).json({ error: 'Failed to fetch token status', details: err.message });
  }
});

async function getOrCreateStripeCustomerByEmail(
  email: string,
  uid: string
): Promise<string> {
  if (!stripe) {
    throw new Error('Stripe not initialized');
  }

  const userPlan = await getUserPlan(uid);
  if (userPlan.stripeCustomerId) {
    return userPlan.stripeCustomerId;
  }

  // Aqui você pode criar o customer no Stripe e salvar em Firestore se quiser
  const customer = await stripe.customers.create({
    email,
    metadata: { uid },
  });

  await updateUserPlan(uid, userPlan.plan, {
    customerId: customer.id,
    subscriptionId: userPlan.stripeSubscriptionId,
    status: userPlan.subscriptionStatus,
  });

  return customer.id;
}

export const tokensRouter = router;
