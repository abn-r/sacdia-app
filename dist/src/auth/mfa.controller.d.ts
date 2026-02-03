import type { Request } from 'express';
import { MfaService } from '../common/services/mfa.service';
import { VerifyMfaDto, UnenrollMfaDto } from './dto/mfa.dto';
export declare class MfaController {
    private readonly mfaService;
    constructor(mfaService: MfaService);
    enrollMfa(req: Request): Promise<import("../common/services/mfa.service").MfaEnrollResponse>;
    verifyMfa(req: Request, dto: VerifyMfaDto): Promise<{
        verified: boolean;
    }>;
    listFactors(req: Request): Promise<import("../common/services/mfa.service").MfaFactor[]>;
    unenrollMfa(req: Request, dto: UnenrollMfaDto): Promise<{
        success: boolean;
        message: string;
    }>;
    getMfaStatus(req: Request): Promise<{
        mfaEnabled: boolean;
        currentLevel: string;
        nextLevel: string | null;
        factors: import("../common/services/mfa.service").MfaFactor[];
    }>;
    private extractToken;
}
