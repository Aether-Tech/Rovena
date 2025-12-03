import { Router } from 'express';
import type { Request, Response } from 'express';
import { updateUserPlan } from '../services/tokenService';

const router = Router();

router.post('/webhook', async (req: Request, res: Response) => {
  try {
    const event = req.body;

    const planMapping: Record<string, 'FREE' | 'BASIC' | 'PRO' | 'ENTERPRISE'> = {
      price_free: 'FREE',
      price_basic: 'BASIC',
      price_pro: 'PRO',
      price_enterprise: 'ENTERPRISE',
    };

    switch (event.type) {
      case 'customer.subscription.created':
      case 'customer.subscription.updated': {
        const subscription = event.data.object;
        const customerId = subscription.customer;
        const subscriptionId = subscription.id;
        const status = subscription.status;
        const priceId = subscription.items?.data[0]?.price?.id;

        // Aqui você conectaria customerId -> uid via Firestore, semelhante ao backend
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
