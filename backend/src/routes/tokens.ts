import { Router } from 'express';
import type { AuthedRequest } from '../middleware/auth';
import type { Response } from 'express';
import Stripe from 'stripe';
import {
  getMonthlyTokenLimit,
  getTokensUsedLast30Days,
  getUserPlan,
  updateUserPlan,
} from '../services/tokenService';

const router = Router();

// Product ID da assinatura Rovena+
export const ROVENA_PLUS_PRODUCT_ID = 'prod_TV9GzjLJOU202c';

// Inicializar Stripe
const stripe = process.env.STRIPE_SECRET_KEY 
  ? new Stripe(process.env.STRIPE_SECRET_KEY, {
      apiVersion: '2024-11-20.acacia',
    })
  : null;

// GET /api/tokens/status - Retorna limite mensal do usuário e uso atual
router.get('/status', async (req: AuthedRequest, res: Response) => {
  if (!req.user) return res.status(401).json({ error: 'Unauthorized' });

  try {
    const monthlyLimit = await getMonthlyTokenLimit(req.user.uid);
    const tokensUsedLast30Days = await getTokensUsedLast30Days(req.user.uid);
    const userPlan = await getUserPlan(req.user.uid);

    // Se temos email e Stripe configurado, verificar assinatura no Stripe
    if (req.user.email && stripe && process.env.STRIPE_SECRET_KEY) {
      try {
        // Garantir que temos o customerId
        let customerId = userPlan.stripeCustomerId;
        if (!customerId) {
          customerId = await getOrCreateStripeCustomerByEmail(req.user.email, req.user.uid);
        }

        // Buscar assinaturas ativas do customer no Stripe
        const subscriptions = await stripe.subscriptions.list({
          customer: customerId,
          status: 'all', // Buscar todas: active, canceled, past_due, etc
          limit: 10,
        });

        console.log(`[tokens] Found ${subscriptions.data.length} subscriptions for ${req.user.email}:`, {
          email: req.user.email,
          customerId: customerId,
          subscriptions: subscriptions.data.map((sub: Stripe.Subscription) => ({
            id: sub.id,
            status: sub.status,
            current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
            items: sub.items.data.map((item: Stripe.SubscriptionItem) => ({
              priceId: item.price.id,
              productId: item.price.product,
              priceNickname: item.price.nickname,
              priceAmount: item.price.unit_amount,
            })),
          })),
        });

        // Se encontrou assinaturas ativas, atualizar no Firestore
        const activeSubscription = subscriptions.data.find(
          (sub: Stripe.Subscription) => sub.status === 'active' || sub.status === 'trialing'
        );

        if (activeSubscription) {
          // Verificar se o produto é o Rovena+
          const rovenaItem = activeSubscription.items.data.find(
            (item: Stripe.SubscriptionItem) => item.price.product === ROVENA_PLUS_PRODUCT_ID
          );

          if (rovenaItem) {
            const priceId = rovenaItem.price.id;
            const priceAmount = rovenaItem.price.unit_amount; // em centavos
            const priceNickname = rovenaItem.price.nickname || '';
            
            console.log(`[tokens] Found Rovena+ subscription:`, {
              priceId,
              priceAmount,
              priceNickname,
              subscriptionId: activeSubscription.id,
            });

            // Mapear priceId ou valor para plano
            // R$ 100/mês = PRO (3000000 tokens)
            // R$ 29-39/mês = BASIC (500000 tokens)
            // R$ 299+/mês = ENTERPRISE (ilimitado)
            let plan: 'BASIC' | 'PRO' | 'ENTERPRISE' = 'BASIC';
            
            // Mapear por valor (em centavos) - mais confiável
            if (priceAmount) {
              const amountInReais = priceAmount / 100;
              if (amountInReais >= 299) {
                plan = 'ENTERPRISE';
              } else if (amountInReais >= 90) { // R$ 90+ = PRO (R$ 100)
                plan = 'PRO';
              } else if (amountInReais >= 25) { // R$ 25+ = BASIC (R$ 29-39)
                plan = 'BASIC';
              }
            }
            
            // Também verificar por priceId se disponível
            if (priceId) {
              const priceIdLower = priceId.toLowerCase();
              if (priceIdLower.includes('enterprise') || priceIdLower.includes('enterprise')) {
                plan = 'ENTERPRISE';
              } else if (priceIdLower.includes('pro') || priceIdLower.includes('100')) {
                plan = 'PRO';
              } else if (priceIdLower.includes('basic') || priceIdLower.includes('29') || priceIdLower.includes('39')) {
                plan = 'BASIC';
              }
            }
            
            // Verificar nickname também
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

            console.log(`[tokens] Mapped to plan: ${plan} (priceId: ${priceId}, amount: ${priceAmount ? priceAmount / 100 : 'N/A'} BRL)`);

            // SEMPRE atualizar no Firestore quando encontrar assinatura ativa
            await updateUserPlan(req.user.uid, plan, {
              customerId: customerId,
              subscriptionId: activeSubscription.id,
              status: activeSubscription.status as 'active' | 'canceled' | 'past_due' | 'trialing',
            });
            
            console.log(`[tokens] Updated user plan from ${userPlan.plan} to ${plan} for ${req.user.email}`);
            
            // Retornar dados atualizados
            const updatedLimit = await getMonthlyTokenLimit(req.user.uid);
            return res.json({
              monthlyLimit: updatedLimit,
              tokensUsedLast30Days,
              plan: plan,
              remaining: updatedLimit === -1 
                ? -1 
                : Math.max(0, updatedLimit - tokensUsedLast30Days),
              subscriptionStatus: activeSubscription.status,
              stripeSubscriptionId: activeSubscription.id,
              stripeCustomerId: customerId,
              syncedFromStripe: true,
            });
          } else {
            console.log(`[tokens] Subscription found but not Rovena+ product for ${req.user.email}`);
          }
        } else {
          console.log(`[tokens] No active subscription found for ${req.user.email}`);
        }
      } catch (stripeError: any) {
        console.error('[tokens] Error syncing with Stripe:', stripeError);
        // Continuar com dados do Firestore mesmo se houver erro no Stripe
      }
    }

    // Se chegou aqui, retornar dados do Firestore
    // Mas se temos subscriptionStatus ativo e plano é FREE, pode ser que não sincronizou ainda
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

/**
 * Busca ou cria um customer no Stripe pelo email
 */
async function getOrCreateStripeCustomerByEmail(
  email: string,
  uid: string
): Promise<string> {
  if (!stripe) {
    throw new Error('Stripe not initialized');
  }

  // Verificar se já temos o customerId salvo no Firestore
  const userPlan = await getUserPlan(uid);
  if (userPlan.stripeCustomerId) {
    // Verificar se o customer ainda existe no Stripe
    try {
      await stripe.customers.retrieve(userPlan.stripeCustomerId);
      return userPlan.stripeCustomerId;
    } catch (error) {
      // Customer não existe mais, vamos criar um novo
      console.log('[tokens] Customer not found in Stripe, creating new one');
    }
  }

  // Buscar customer existente no Stripe pelo email
  const customers = await stripe.customers.list({
    email: email,
    limit: 1,
  });

  let customerId: string;

  if (customers.data.length > 0) {
    // Customer já existe, usar o ID existente
    customerId = customers.data[0].id;
    console.log('[tokens] Found existing Stripe customer:', customerId);
  } else {
    // Criar novo customer no Stripe
    const customer = await stripe.customers.create({
      email: email,
      metadata: {
        firebase_uid: uid,
      },
    });
    customerId = customer.id;
    console.log('[tokens] Created new Stripe customer:', customerId);
  }

  // Salvar customerId no Firestore
  await updateUserPlan(uid, userPlan.plan, {
    customerId: customerId,
  });

  return customerId;
}

// POST /api/tokens/cancel-subscription - Cancela a assinatura do usuário
router.post('/cancel-subscription', async (req: AuthedRequest, res: Response) => {
  if (!req.user) return res.status(401).json({ error: 'Unauthorized' });

  try {
    const userPlan = await getUserPlan(req.user.uid);
    
    if (!userPlan.stripeSubscriptionId) {
      return res.status(400).json({ error: 'No active subscription found' });
    }

    // Verificar se o Stripe está configurado
    if (!stripe || !process.env.STRIPE_SECRET_KEY) {
      console.error('[tokens] STRIPE_SECRET_KEY not configured');
      return res.status(500).json({ 
        error: 'Stripe not configured', 
        details: 'STRIPE_SECRET_KEY environment variable is missing' 
      });
    }

    // Garantir que temos o customerId (buscar/criar pelo email se necessário)
    if (!userPlan.stripeCustomerId && req.user.email) {
      const customerId = await getOrCreateStripeCustomerByEmail(req.user.email, req.user.uid);
      console.log('[tokens] Customer ID obtained:', customerId);
    }

    // Cancelar assinatura no Stripe
    // Segundo a documentação: https://docs.stripe.com/api/subscriptions/cancel
    // O cancelamento pode ser imediato ou ao final do período de cobrança
    try {
      const canceledSubscription = await stripe.subscriptions.cancel(
        userPlan.stripeSubscriptionId,
        {
          // cancel_at_period_end: true - para cancelar ao final do período
          // Sem esse parâmetro, cancela imediatamente
        }
      );

      console.log('[tokens] Subscription canceled in Stripe:', {
        subscriptionId: canceledSubscription.id,
        status: canceledSubscription.status,
      });

      // Atualizar status no Firestore
      // O webhook do Stripe também atualizará, mas fazemos aqui para resposta imediata
      await updateUserPlan(req.user.uid, 'FREE', {
        status: canceledSubscription.status === 'canceled' ? 'canceled' : 'active',
        subscriptionId: canceledSubscription.id,
      });

      return res.json({ 
        success: true, 
        message: 'Subscription canceled successfully',
        plan: 'FREE',
        subscriptionStatus: canceledSubscription.status,
      });
    } catch (stripeError: any) {
      // Tratar erros específicos do Stripe
      console.error('[tokens] Stripe API error:', stripeError);
      
      if (stripeError.type === 'StripeInvalidRequestError') {
        return res.status(400).json({ 
          error: 'Invalid subscription', 
          details: stripeError.message 
        });
      }
      
      throw stripeError; // Re-throw para ser capturado pelo catch externo
    }
  } catch (err: any) {
    console.error('[tokens] cancel subscription error', err);
    return res.status(500).json({ 
      error: 'Failed to cancel subscription', 
      details: err.message 
    });
  }
});

// GET /api/tokens/test-subscription - Endpoint de teste para verificar assinatura
router.get('/test-subscription', async (req: AuthedRequest, res: Response) => {
  if (!req.user) return res.status(401).json({ error: 'Unauthorized' });

  if (!req.user.email) {
    return res.status(400).json({ error: 'Email not available' });
  }

  if (!stripe || !process.env.STRIPE_SECRET_KEY) {
    return res.status(500).json({ error: 'Stripe not configured' });
  }

  try {
    const email = req.user.email;
    console.log(`[tokens/test] Testing subscription lookup for: ${email}`);

    // Buscar customer pelo email
    const customers = await stripe.customers.list({
      email: email,
      limit: 10,
    });

    console.log(`[tokens/test] Found ${customers.data.length} customers with email ${email}`);

    if (customers.data.length === 0) {
      return res.json({
        email: email,
        found: false,
        message: 'No customer found with this email in Stripe',
      });
    }

    // Buscar assinaturas para todos os customers encontrados
    const results = await Promise.all(
      customers.data.map(async (customer: Stripe.Customer) => {
        const subscriptions = await stripe.subscriptions.list({
          customer: customer.id,
          status: 'all',
          limit: 10,
        });

        const rovenaSubscriptions = subscriptions.data.filter((sub: Stripe.Subscription) =>
          sub.items.data.some(
            (item: Stripe.SubscriptionItem) => item.price.product === ROVENA_PLUS_PRODUCT_ID
          )
        );

        return {
          customerId: customer.id,
          customerEmail: customer.email,
          totalSubscriptions: subscriptions.data.length,
          rovenaSubscriptions: rovenaSubscriptions.map((sub: Stripe.Subscription) => ({
            id: sub.id,
            status: sub.status,
            current_period_start: new Date(sub.current_period_start * 1000).toISOString(),
            current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
            cancel_at_period_end: sub.cancel_at_period_end,
            items: sub.items.data.map((item: Stripe.SubscriptionItem) => ({
              priceId: item.price.id,
              productId: item.price.product,
              productName: item.price.nickname || 'N/A',
            })),
          })),
        };
      })
    );

    return res.json({
      email: email,
      found: true,
      customers: results,
      summary: {
        totalCustomers: customers.data.length,
        totalRovenaSubscriptions: results.reduce(
          (sum: number, r: any) => sum + r.rovenaSubscriptions.length,
          0
        ),
        activeRovenaSubscriptions: results.reduce(
          (sum: number, r: any) =>
            sum +
            r.rovenaSubscriptions.filter((s: any) => s.status === 'active').length,
          0
        ),
      },
    });
  } catch (err: any) {
    console.error('[tokens/test] Error:', err);
    return res.status(500).json({
      error: 'Test failed',
      details: err.message,
    });
  }
});

export const tokensRouter = router;

