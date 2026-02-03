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
var MfaService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.MfaService = void 0;
const common_1 = require("@nestjs/common");
const supabase_js_1 = require("@supabase/supabase-js");
let MfaService = MfaService_1 = class MfaService {
    logger = new common_1.Logger(MfaService_1.name);
    supabase;
    constructor() {
        this.supabase = (0, supabase_js_1.createClient)(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);
    }
    async enrollMfa(accessToken) {
        try {
            const { data: sessionData, error: sessionError } = await this.supabase.auth.setSession({
                access_token: accessToken,
                refresh_token: '',
            });
            if (sessionError) {
                throw new common_1.BadRequestException('Invalid session');
            }
            const { data, error } = await this.supabase.auth.mfa.enroll({
                factorType: 'totp',
                friendlyName: 'SACDIA Authenticator',
            });
            if (error) {
                this.logger.error(`MFA enrollment failed: ${error.message}`);
                throw new common_1.BadRequestException(error.message);
            }
            this.logger.log(`MFA enrollment initiated for user`);
            return {
                factorId: data.id,
                qrCode: data.totp.qr_code,
                secret: data.totp.secret,
                uri: data.totp.uri,
            };
        }
        catch (error) {
            if (error instanceof common_1.BadRequestException)
                throw error;
            this.logger.error(`MFA enrollment error: ${error}`);
            throw new common_1.BadRequestException('Failed to enroll MFA');
        }
    }
    async verifyAndActivateMfa(accessToken, factorId, code) {
        try {
            await this.supabase.auth.setSession({
                access_token: accessToken,
                refresh_token: '',
            });
            const { data: challengeData, error: challengeError } = await this.supabase.auth.mfa.challenge({ factorId });
            if (challengeError) {
                throw new common_1.BadRequestException(challengeError.message);
            }
            const { data, error } = await this.supabase.auth.mfa.verify({
                factorId,
                challengeId: challengeData.id,
                code,
            });
            if (error) {
                this.logger.warn(`MFA verification failed: ${error.message}`);
                throw new common_1.UnauthorizedException('Invalid MFA code');
            }
            this.logger.log(`MFA verified and activated`);
            return { verified: true };
        }
        catch (error) {
            if (error instanceof common_1.BadRequestException ||
                error instanceof common_1.UnauthorizedException) {
                throw error;
            }
            throw new common_1.BadRequestException('MFA verification failed');
        }
    }
    async verifyMfaCode(accessToken, factorId, code) {
        try {
            await this.supabase.auth.setSession({
                access_token: accessToken,
                refresh_token: '',
            });
            const { data: challengeData, error: challengeError } = await this.supabase.auth.mfa.challenge({ factorId });
            if (challengeError) {
                return false;
            }
            const { error } = await this.supabase.auth.mfa.verify({
                factorId,
                challengeId: challengeData.id,
                code,
            });
            return !error;
        }
        catch {
            return false;
        }
    }
    async listFactors(accessToken) {
        try {
            await this.supabase.auth.setSession({
                access_token: accessToken,
                refresh_token: '',
            });
            const { data, error } = await this.supabase.auth.mfa.listFactors();
            if (error) {
                throw new common_1.BadRequestException(error.message);
            }
            return (data.totp || []).map((factor) => ({
                id: factor.id,
                friendlyName: factor.friendly_name || 'Authenticator',
                factorType: factor.factor_type,
                status: factor.status,
                createdAt: factor.created_at,
            }));
        }
        catch (error) {
            if (error instanceof common_1.BadRequestException)
                throw error;
            throw new common_1.BadRequestException('Failed to list MFA factors');
        }
    }
    async unenrollFactor(accessToken, factorId) {
        try {
            await this.supabase.auth.setSession({
                access_token: accessToken,
                refresh_token: '',
            });
            const { error } = await this.supabase.auth.mfa.unenroll({ factorId });
            if (error) {
                throw new common_1.BadRequestException(error.message);
            }
            this.logger.log(`MFA factor ${factorId} unenrolled`);
        }
        catch (error) {
            if (error instanceof common_1.BadRequestException)
                throw error;
            throw new common_1.BadRequestException('Failed to unenroll MFA factor');
        }
    }
    async hasMfaEnabled(accessToken) {
        const factors = await this.listFactors(accessToken);
        return factors.some((f) => f.status === 'verified');
    }
    async getAuthenticatorAssuranceLevel(accessToken) {
        try {
            await this.supabase.auth.setSession({
                access_token: accessToken,
                refresh_token: '',
            });
            const { data, error } = await this.supabase.auth.mfa.getAuthenticatorAssuranceLevel();
            if (error) {
                throw new common_1.BadRequestException(error.message);
            }
            return {
                currentLevel: data.currentLevel || 'aal1',
                nextLevel: data.nextLevel,
            };
        }
        catch (error) {
            if (error instanceof common_1.BadRequestException)
                throw error;
            return { currentLevel: 'aal1', nextLevel: null };
        }
    }
};
exports.MfaService = MfaService;
exports.MfaService = MfaService = MfaService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [])
], MfaService);
//# sourceMappingURL=mfa.service.js.map