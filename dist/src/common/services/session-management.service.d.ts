import type { Cache } from 'cache-manager';
export interface UserSession {
    sessionId: string;
    userId: string;
    deviceInfo: string;
    ipAddress: string;
    createdAt: Date;
    lastActivity: Date;
}
export declare class SessionManagementService {
    private cacheManager;
    private readonly logger;
    private readonly SESSION_PREFIX;
    private readonly MAX_SESSIONS;
    private readonly SESSION_TTL;
    constructor(cacheManager: Cache);
    createSession(userId: string, sessionId: string, deviceInfo: string, ipAddress: string): Promise<{
        created: boolean;
        removedSession?: string;
    }>;
    getUserSessions(userId: string): Promise<UserSession[]>;
    updateSessionActivity(userId: string, sessionId: string): Promise<void>;
    isValidSession(userId: string, sessionId: string): Promise<boolean>;
    removeSession(userId: string, sessionId: string): Promise<void>;
    removeAllSessions(userId: string): Promise<number>;
    getSessionStats(userId: string): Promise<{
        activeSessions: number;
        maxSessions: number;
        sessions: UserSession[];
    }>;
    private getSessionKey;
    private getUserSessionListKey;
    private getUserSessionIds;
    private addToUserSessionList;
    private removeFromUserSessionList;
}
