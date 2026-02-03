import type { Cache } from 'cache-manager';
export declare class TokenBlacklistService {
    private cacheManager;
    private readonly logger;
    private readonly BLACKLIST_PREFIX;
    constructor(cacheManager: Cache);
    blacklistToken(token: string, expiresInSeconds: number): Promise<void>;
    isBlacklisted(token: string): Promise<boolean>;
    blacklistAllUserTokens(userId: string, expiresInSeconds?: number): Promise<void>;
    isUserBlacklisted(userId: string, tokenIssuedAt: number): Promise<boolean>;
    private getBlacklistKey;
    private hashToken;
}
