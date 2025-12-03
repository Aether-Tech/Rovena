"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PLANS = void 0;
exports.getUserPlan = getUserPlan;
exports.getMonthlyTokenLimit = getMonthlyTokenLimit;
exports.getTokensUsedLast30Days = getTokensUsedLast30Days;
exports.canUseTokens = canUseTokens;
exports.recordTokenUsage = recordTokenUsage;
exports.estimateTokenCount = estimateTokenCount;
exports.updateUserPlan = updateUserPlan;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const db = firebase_admin_1.default.firestore();
exports.PLANS = {
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
};
async function getUserPlan(uid) {
    try {
        const userDoc = await db.collection('users').doc(uid).get();
        if (!userDoc.exists) {
            const defaultPlan = { plan: 'FREE' };
            await db.collection('users').doc(uid).set(defaultPlan, { merge: true });
            return defaultPlan;
        }
        const data = userDoc.data();
        return {
            plan: data?.plan || 'FREE',
            stripeCustomerId: data?.stripeCustomerId,
            stripeSubscriptionId: data?.stripeSubscriptionId,
            subscriptionStatus: data?.subscriptionStatus,
        };
    }
    catch (error) {
        console.error('[tokenService] Error fetching user plan:', error);
        return { plan: 'FREE' };
    }
}
async function getMonthlyTokenLimit(uid) {
    const userPlan = await getUserPlan(uid);
    const planConfig = exports.PLANS[userPlan.plan];
    if (userPlan.stripeSubscriptionId && userPlan.subscriptionStatus !== 'active') {
        return exports.PLANS.FREE.monthlyTokenLimit;
    }
    return planConfig.monthlyTokenLimit;
}
async function getTokensUsedLast30Days(uid) {
    try {
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        const usageRef = db.collection('users').doc(uid).collection('tokenUsage');
        const snapshot = await usageRef.where('date', '>=', formatDate(thirtyDaysAgo)).get();
        let total = 0;
        snapshot.forEach((doc) => {
            const data = doc.data();
            total += data.tokens || 0;
        });
        return total;
    }
    catch (error) {
        console.error('[tokenService] Error calculating usage:', error);
        return 0;
    }
}
async function canUseTokens(uid, estimatedTokens) {
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
async function recordTokenUsage(uid, tokens, date = new Date()) {
    try {
        const dateKey = formatDate(date);
        const usageRef = db
            .collection('users')
            .doc(uid)
            .collection('tokenUsage')
            .doc(dateKey);
        await usageRef.set({
            date: dateKey,
            tokens: firebase_admin_1.default.firestore.FieldValue.increment(tokens),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        await cleanupOldUsage(uid);
    }
    catch (error) {
        console.error('[tokenService] Error recording usage:', error);
    }
}
async function cleanupOldUsage(uid) {
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
    }
    catch (error) {
        console.error('[tokenService] Error cleaning up old usage:', error);
    }
}
function formatDate(date) {
    return date.toISOString().split('T')[0];
}
function estimateTokenCount(messages, model) {
    const totalChars = messages.reduce((sum, msg) => sum + (msg.content?.length || 0), 0);
    let estimated = Math.ceil(totalChars / 4);
    if (model.includes('gpt-4')) {
        estimated = Math.ceil(estimated * 1.2);
    }
    else if (model.includes('gpt-3.5')) {
        estimated = Math.ceil(estimated * 0.9);
    }
    estimated += messages.length * 3;
    return estimated;
}
async function updateUserPlan(uid, plan, stripeData) {
    try {
        const data = { plan };
        if (stripeData) {
            if (stripeData.customerId)
                data.stripeCustomerId = stripeData.customerId;
            if (stripeData.subscriptionId)
                data.stripeSubscriptionId = stripeData.subscriptionId;
            if (stripeData.status)
                data.subscriptionStatus = stripeData.status;
        }
        await db.collection('users').doc(uid).set(data, { merge: true });
    }
    catch (error) {
        console.error('[tokenService] Error updating user plan:', error);
    }
}
