"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.authMiddleware = authMiddleware;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
// Initialize Firebase Admin once per process using default credentials
// In Cloud Functions, the runtime provides a service account automatically
if (!firebase_admin_1.default.apps.length) {
    firebase_admin_1.default.initializeApp();
}
async function authMiddleware(req, res, next) {
    const authHeader = req.headers.authorization || '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : undefined;
    if (!token) {
        return res.status(401).json({ error: 'Missing Authorization header' });
    }
    try {
        const decoded = await firebase_admin_1.default.auth().verifyIdToken(token);
        req.user = { uid: decoded.uid, email: decoded.email };
        return next();
    }
    catch (err) {
        console.error('[auth] invalid token', err);
        return res.status(401).json({ error: 'Invalid token' });
    }
}
