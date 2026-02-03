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
var TokenBlacklistService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.TokenBlacklistService = void 0;
const common_1 = require("@nestjs/common");
const cache_manager_1 = require("@nestjs/cache-manager");
let TokenBlacklistService = TokenBlacklistService_1 = class TokenBlacklistService {
    cacheManager;
    logger = new common_1.Logger(TokenBlacklistService_1.name);
    BLACKLIST_PREFIX = 'token:blacklist:';
    constructor(cacheManager) {
        this.cacheManager = cacheManager;
    }
    async blacklistToken(token, expiresInSeconds) {
        const key = this.getBlacklistKey(token);
        await this.cacheManager.set(key, 'revoked', expiresInSeconds * 1000);
        this.logger.log(`Token blacklisted, expires in ${expiresInSeconds}s`);
    }
    async isBlacklisted(token) {
        const key = this.getBlacklistKey(token);
        const result = await this.cacheManager.get(key);
        return result === 'revoked';
    }
    async blacklistAllUserTokens(userId, expiresInSeconds = 86400) {
        const key = `${this.BLACKLIST_PREFIX}user:${userId}:all`;
        await this.cacheManager.set(key, Date.now().toString(), expiresInSeconds * 1000);
        this.logger.warn(`All tokens blacklisted for user ${userId}`);
    }
    async isUserBlacklisted(userId, tokenIssuedAt) {
        const key = `${this.BLACKLIST_PREFIX}user:${userId}:all`;
        const blacklistTime = await this.cacheManager.get(key);
        if (!blacklistTime)
            return false;
        return tokenIssuedAt < parseInt(blacklistTime, 10);
    }
    getBlacklistKey(token) {
        const hash = this.hashToken(token);
        return `${this.BLACKLIST_PREFIX}${hash}`;
    }
    hashToken(token) {
        return token.slice(-32);
    }
};
exports.TokenBlacklistService = TokenBlacklistService;
exports.TokenBlacklistService = TokenBlacklistService = TokenBlacklistService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, common_1.Inject)(cache_manager_1.CACHE_MANAGER)),
    __metadata("design:paramtypes", [Object])
], TokenBlacklistService);
//# sourceMappingURL=token-blacklist.service.js.map