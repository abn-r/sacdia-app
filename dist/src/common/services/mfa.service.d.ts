export interface MfaEnrollResponse {
    factorId: string;
    qrCode: string;
    secret: string;
    uri: string;
}
export interface MfaFactor {
    id: string;
    friendlyName: string;
    factorType: string;
    status: string;
    createdAt: string;
}
export declare class MfaService {
    private readonly logger;
    private supabase;
    constructor();
    enrollMfa(accessToken: string): Promise<MfaEnrollResponse>;
    verifyAndActivateMfa(accessToken: string, factorId: string, code: string): Promise<{
        verified: boolean;
    }>;
    verifyMfaCode(accessToken: string, factorId: string, code: string): Promise<boolean>;
    listFactors(accessToken: string): Promise<MfaFactor[]>;
    unenrollFactor(accessToken: string, factorId: string): Promise<void>;
    hasMfaEnabled(accessToken: string): Promise<boolean>;
    getAuthenticatorAssuranceLevel(accessToken: string): Promise<{
        currentLevel: string;
        nextLevel: string | null;
    }>;
}
