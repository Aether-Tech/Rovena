"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.tokensRouter = exports.ROVENA_PLUS_PRODUCT_ID = void 0;
const express_1 = require("express");
const stripe_1 = __importDefault(require("stripe"));
const functions = __importStar(require("firebase-functions"));
const tokenService_1 = require("../services/tokenService");
const router = (0, express_1.Router)();
exports.ROVENA_PLUS_PRODUCT_ID = 'prod_TV9GzjLJOU202c';
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret;
const stripe = STRIPE_SECRET_KEY
    ? new stripe_1.default(STRIPE_SECRET_KEY, {
        apiVersion: '2024-06-20',
    })
    : null;
router.get('/status', async (req, res) => {
    if (!req.user)
        return res.status(401).json({ error: 'Unauthorized' });
    try {
        const monthlyLimit = await (0, tokenService_1.getMonthlyTokenLimit)(req.user.uid);
        const tokensUsedLast30Days = await (0, tokenService_1.getTokensUsedLast30Days)(req.user.uid);
        const userPlan = await (0, tokenService_1.getUserPlan)(req.user.uid);
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
                const activeSubscription = subscriptions.data.find((sub) => sub.status === 'active' || sub.status === 'trialing');
                if (activeSubscription) {
                    const rovenaItem = activeSubscription.items.data.find((item) => item.price.product === exports.ROVENA_PLUS_PRODUCT_ID);
                    if (rovenaItem) {
                        const priceId = rovenaItem.price.id;
                        const priceAmount = rovenaItem.price.unit_amount;
                        const priceNickname = rovenaItem.price.nickname || '';
                        let plan = 'BASIC';
                        if (priceAmount) {
                            const amountInReais = priceAmount / 100;
                            if (amountInReais >= 299) {
                                plan = 'ENTERPRISE';
                            }
                            else if (amountInReais >= 90) {
                                plan = 'PRO';
                            }
                            else if (amountInReais >= 25) {
                                plan = 'BASIC';
                            }
                        }
                        if (priceId) {
                            const priceIdLower = priceId.toLowerCase();
                            if (priceIdLower.includes('enterprise')) {
                                plan = 'ENTERPRISE';
                            }
                            else if (priceIdLower.includes('pro') || priceIdLower.includes('100')) {
                                plan = 'PRO';
                            }
                            else if (priceIdLower.includes('basic') ||
                                priceIdLower.includes('29') ||
                                priceIdLower.includes('39')) {
                                plan = 'BASIC';
                            }
                        }
                        if (priceNickname) {
                            const nicknameLower = priceNickname.toLowerCase();
                            if (nicknameLower.includes('enterprise')) {
                                plan = 'ENTERPRISE';
                            }
                            else if (nicknameLower.includes('pro')) {
                                plan = 'PRO';
                            }
                            else if (nicknameLower.includes('basic')) {
                                plan = 'BASIC';
                            }
                        }
                        await (0, tokenService_1.updateUserPlan)(req.user.uid, plan, {
                            customerId: customerId,
                            subscriptionId: activeSubscription.id,
                            status: activeSubscription.status,
                        });
                        const updatedLimit = await (0, tokenService_1.getMonthlyTokenLimit)(req.user.uid);
                        return res.json({
                            monthlyLimit: updatedLimit,
                            tokensUsedLast30Days,
                            plan: plan,
                            remaining: updatedLimit === -1 ? -1 : Math.max(0, updatedLimit - tokensUsedLast30Days),
                            subscriptionStatus: activeSubscription.status,
                            stripeSubscriptionId: activeSubscription.id,
                            stripeCustomerId: customerId,
                            syncedFromStripe: true,
                        });
                    }
                }
            }
            catch (stripeError) {
                console.error('[tokens] Error syncing with Stripe:', stripeError);
            }
        }
        const finalPlan = userPlan.plan;
        const finalLimit = await (0, tokenService_1.getMonthlyTokenLimit)(req.user.uid);
        return res.json({
            monthlyLimit: finalLimit,
            tokensUsedLast30Days,
            plan: finalPlan,
            remaining: finalLimit === -1 ? -1 : Math.max(0, finalLimit - tokensUsedLast30Days),
            subscriptionStatus: userPlan.subscriptionStatus,
            stripeSubscriptionId: userPlan.stripeSubscriptionId,
            stripeCustomerId: userPlan.stripeCustomerId,
        });
    }
    catch (err) {
        console.error('[tokens] error', err);
        return res.status(500).json({ error: 'Failed to fetch token status', details: err.message });
    }
});
async function getOrCreateStripeCustomerByEmail(email, uid) {
    if (!stripe) {
        throw new Error('Stripe not initialized');
    }
    const userPlan = await (0, tokenService_1.getUserPlan)(uid);
    if (userPlan.stripeCustomerId) {
        return userPlan.stripeCustomerId;
    }
    // Aqui você pode criar o customer no Stripe e salvar em Firestore se quiser
    const customer = await stripe.customers.create({
        email,
        metadata: { uid },
    });
    await (0, tokenService_1.updateUserPlan)(uid, userPlan.plan, {
        customerId: customer.id,
        subscriptionId: userPlan.stripeSubscriptionId,
        status: userPlan.subscriptionStatus,
    });
    return customer.id;
}
exports.tokensRouter = router;
