import { Router } from 'express';
import type { Request, Response } from 'express';
import { updateUserPlan } from '../services/tokenService';

const router = Router();

/**
 * Webhook do Stripe para atualizar planos dos usuários
 * 
 * Configure no Stripe Dashboard:
 * - Endpoint: https://api.rovena.app/api/stripe/webhook
 * - Events: customer.subscription.created, customer.subscription.updated, customer.subscription.deleted
 */
router.post('/webhook', async (req: Request, res: Response) => {
  // IMPORTANTE: Verificar assinatura do webhook do Stripe
  // const sig = req.headers['stripe-signature'];
  // const event = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET!);
  
  // Por enquanto, vamos processar eventos básicos
  // Em produção, você DEVE verificar a assinatura do Stripe
  
  try {
    const event = req.body;
    
    // Mapear planos do Stripe para planos internos
    const planMapping: Record<string, 'FREE' | 'BASIC' | 'PRO' | 'ENTERPRISE'> = {
      'price_free': 'FREE',
      'price_basic': 'BASIC',
      'price_pro': 'PRO',
      'price_enterprise': 'ENTERPRISE',
    };
    
    switch (event.type) {
      case 'customer.subscription.created':
      case 'customer.subscription.updated': {
        const subscription = event.data.object;
        const customerId = subscription.customer;
        const subscriptionId = subscription.id;
        const status = subscription.status;
        const priceId = subscription.items?.data[0]?.price?.id;
        
        // Buscar UID do usuário pelo customerId do Stripe
        // Você precisa ter uma coleção que mapeia customerId -> uid
        // Por exemplo: await db.collection('stripeCustomers').doc(customerId).get()
        
        // Exemplo de como atualizar:
        // const customerDoc = await db.collection('stripeCustomers').doc(customerId).get();
        // const uid = customerDoc.data()?.uid;
        // if (uid) {
        //   const plan = planMapping[priceId] || 'FREE';
        //   await updateUserPlan(uid, plan, {
        //     customerId,
        //     subscriptionId,
        //     status,
        //   });
        // }
        
        console.log('[stripe-webhook] Subscription updated:', {
          customerId,
          subscriptionId,
          status,
          priceId,
        });
        break;
      }
      
      case 'customer.subscription.deleted': {
        const subscription = event.data.object;
        const customerId = subscription.customer;
        
        // Rebaixar usuário para plano FREE quando cancelar
        // const customerDoc = await db.collection('stripeCustomers').doc(customerId).get();
        // const uid = customerDoc.data()?.uid;
        // if (uid) {
        //   await updateUserPlan(uid, 'FREE', {
        //     customerId,
        //     status: 'canceled',
        //   });
        // }
        
        console.log('[stripe-webhook] Subscription deleted:', { customerId });
        break;
      }
    }
    
    res.json({ received: true });
  } catch (error: any) {
    console.error('[stripe-webhook] Error:', error);
    res.status(400).json({ error: 'Webhook processing failed' });
  }
});

export const stripeWebhookRouter = router;

