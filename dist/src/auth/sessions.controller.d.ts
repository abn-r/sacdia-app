import type { Request } from 'express';
import { SessionManagementService } from '../common/services/session-management.service';
import { TokenBlacklistService } from '../common/services/token-blacklist.service';
export declare class SessionsController {
    private readonly sessionService;
    private readonly tokenBlacklistService;
    constructor(sessionService: SessionManagementService, tokenBlacklistService: TokenBlacklistService);
    listSessions(req: Request): Promise<{
        activeSessions: number;
        maxSessions: number;
        sessions: import("../common/services/session-management.service").UserSession[];
    }>;
    closeSession(req: Request, sessionId: string): Promise<{
        success: boolean;
        message: string;
    }>;
    closeAllSessions(req: Request): Promise<{
        success: boolean;
        message: string;
    }>;
}
