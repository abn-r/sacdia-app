"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var SessionManagementService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.SessionManagementService = void 0;
const common_1 = require("@nestjs/common");
const cache_manager_1 = require("@nestjs/cache-manager");
let SessionManagementService = SessionManagementService_1 = class SessionManagementService {
    cacheManager;
    logger = new common_1.Logger(SessionManagementService_1.name);
    SESSION_PREFIX = 'session:';
    MAX_SESSIONS = 5;
    SESSION_TTL = 86400;
    constructor(cacheManager) {
        this.cacheManager = cacheManager;
    }
    async createSession(userId, sessionId, deviceInfo, ipAddress) {
        const sessions = await this.getUserSessions(userId);
        let removedSession;
        if (sessions.length >= this.MAX_SESSIONS) {
            const oldestSession = sessions.sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime())[0];
            await this.removeSession(userId, oldestSession.sessionId);
            removedSession = oldestSession.sessionId;
            this.logger.warn(`Session limit reached for user ${userId}. Removed oldest session.`);
        }
        const session = {
            sessionId,
            userId,
            deviceInfo,
            ipAddress,
            createdAt: new Date(),
            lastActivity: new Date(),
        };
        const key = this.getSessionKey(userId, sessionId);
        await this.cacheManager.set(key, JSON.stringify(session), this.SESSION_TTL * 1000);
        await this.addToUserSessionList(userId, sessionId);
        this.logger.log(`New session created for user ${userId}: ${sessionId}`);
        return { created: true, removedSession };
    }
    async getUserSessions(userId) {
        const sessionIds = await this.getUserSessionIds(userId);
        const sessions = [];
        for (const sessionId of sessionIds) {
            const key = this.getSessionKey(userId, sessionId);
            const sessionData = await this.cacheManager.get(key);
            if (sessionData) {
                sessions.push(JSON.parse(sessionData));
            }
        }
        return sessions;
    }
    async updateSessionActivity(userId, sessionId) {
        const key = this.getSessionKey(userId, sessionId);
        const sessionData = await this.cacheManager.get(key);
        if (sessionData) {
            const session = JSON.parse(sessionData);
            session.lastActivity = new Date();
            await this.cacheManager.set(key, JSON.stringify(session), this.SESSION_TTL * 1000);
        }
    }
    async isValidSession(userId, sessionId) {
        const key = this.getSessionKey(userId, sessionId);
        const session = await this.cacheManager.get(key);
        return session !== null && session !== undefined;
    }
    async removeSession(userId, sessionId) {
        const key = this.getSessionKey(userId, sessionId);
        await this.cacheManager.del(key);
        await this.removeFromUserSessionList(userId, sessionId);
        this.logger.log(`Session removed: ${sessionId} for user ${userId}`);
    }
    async removeAllSessions(userId) {
        const sessionIds = await this.getUserSessionIds(userId);
        for (const sessionId of sessionIds) {
            const key = this.getSessionKey(userId, sessionId);
            await this.cacheManager.del(key);
        }
        await this.cacheManager.del(this.getUserSessionListKey(userId));
        this.logger.warn(`All ${sessionIds.length} sessions removed for user ${userId}`);
        return sessionIds.length;
    }
    async getSessionStats(userId) {
        const sessions = await this.getUserSessions(userId);
        return {
            activeSessions: sessions.length,
            maxSessions: this.MAX_SESSIONS,
            sessions,
        };
    }
    getSessionKey(userId, sessionId) {
        return `${this.SESSION_PREFIX}${userId}:${sessionId}`;
    }
    getUserSessionListKey(userId) {
        return `${this.SESSION_PREFIX}list:${userId}`;
    }
    async getUserSessionIds(userId) {
        const key = this.getUserSessionListKey(userId);
        const data = await this.cacheManager.get(key);
        return data ? JSON.parse(data) : [];
    }
    async addToUserSessionList(userId, sessionId) {
        const sessionIds = await this.getUserSessionIds(userId);
        if (!sessionIds.includes(sessionId)) {
            sessionIds.push(sessionId);
            const key = this.getUserSessionListKey(userId);
            await this.cacheManager.set(key, JSON.stringify(sessionIds), this.SESSION_TTL * 1000);
        }
    }
    async removeFromUserSessionList(userId, sessionId) {
        const sessionIds = await this.getUserSessionIds(userId);
        const filtered = sessionIds.filter((id) => id !== sessionId);
        const key = this.getUserSessionListKey(userId);
        await this.cacheManager.set(key, JSON.stringify(filtered), this.SESSION_TTL * 1000);
    }
};
exports.SessionManagementService = SessionManagementService;
exports.SessionManagementService = SessionManagementService = SessionManagementService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, common_1.Inject)(cache_manager_1.CACHE_MANAGER)),
    __metadata("design:paramtypes", [Object])
], SessionManagementService);
//# sourceMappingURL=session-management.service.js.map