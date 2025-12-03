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
Object.defineProperty(exports, "__esModule", { value: true });
exports.imageRouter = void 0;
const express_1 = require("express");
const openai_1 = require("openai");
const functions = __importStar(require("firebase-functions"));
const tokenService_1 = require("../services/tokenService");
const router = (0, express_1.Router)();
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || functions.config().openai?.key;
if (!OPENAI_API_KEY) {
    console.warn('[image] OPENAI_API_KEY is not set; image route will fail until configured');
}
const openai = new openai_1.OpenAI({
    apiKey: OPENAI_API_KEY,
});
router.post('/', async (req, res) => {
    if (!req.user)
        return res.status(401).json({ error: 'Unauthorized' });
    const { prompt } = req.body;
    if (!prompt) {
        return res.status(400).json({ error: 'prompt is required' });
    }
    try {
        const imageCost = tokenService_1.PLANS.FREE.imageGenerationCost;
        const tokenCheck = await (0, tokenService_1.canUseTokens)(req.user.uid, imageCost);
        if (!tokenCheck.allowed) {
            return res.status(429).json({
                error: 'Token limit exceeded',
                message: tokenCheck.reason,
                remaining: tokenCheck.remaining,
            });
        }
        const result = await openai.images.generate({
            model: 'dall-e-3',
            prompt,
            n: 1,
            size: '1024x1024',
        });
        const url = result.data?.[0]?.url;
        if (!url) {
            return res.status(500).json({ error: 'Image provider did not return URL' });
        }
        await (0, tokenService_1.recordTokenUsage)(req.user.uid, imageCost);
        return res.json({ url });
    }
    catch (err) {
        console.error('[image] error', err.response?.data || err.message || err);
        if (err.status === 429) {
            return res.status(429).json({
                error: 'Rate limit exceeded',
                details: 'OpenAI rate limit reached. Please try again later.',
            });
        }
        return res.status(500).json({ error: 'Image provider error', details: err.message });
    }
});
exports.imageRouter = router;
