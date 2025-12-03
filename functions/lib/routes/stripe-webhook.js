"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.stripeWebhookRouter = void 0;
const express_1 = require("express");
const router = (0, express_1.Router)();
router.post('/webhook', async (req, res) => {
    try {
        const event = req.body;
        const planMapping = {
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
    }
    catch (error) {
        console.error('[stripe-webhook] Error:', error);
        res.status(400).json({ error: 'Webhook processing failed' });
    }
});
exports.stripeWebhookRouter = router;
