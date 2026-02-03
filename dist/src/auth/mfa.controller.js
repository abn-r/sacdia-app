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
Object.defineProperty(exports, "__esModule", { value: true });
exports.MfaController = void 0;
const openapi = require("@nestjs/swagger");
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const jwt_auth_guard_1 = require("../common/guards/jwt-auth.guard");
const mfa_service_1 = require("../common/services/mfa.service");
const mfa_dto_1 = require("./dto/mfa.dto");
let MfaController = class MfaController {
    mfaService;
    constructor(mfaService) {
        this.mfaService = mfaService;
    }
    async enrollMfa(req) {
        const token = this.extractToken(req);
        return this.mfaService.enrollMfa(token);
    }
    async verifyMfa(req, dto) {
        const token = this.extractToken(req);
        return this.mfaService.verifyAndActivateMfa(token, dto.factorId, dto.code);
    }
    async listFactors(req) {
        const token = this.extractToken(req);
        return this.mfaService.listFactors(token);
    }
    async unenrollMfa(req, dto) {
        const token = this.extractToken(req);
        await this.mfaService.unenrollFactor(token, dto.factorId);
        return { success: true, message: '2FA disabled successfully' };
    }
    async getMfaStatus(req) {
        const token = this.extractToken(req);
        const [enabled, level, factors] = await Promise.all([
            this.mfaService.hasMfaEnabled(token),
            this.mfaService.getAuthenticatorAssuranceLevel(token),
            this.mfaService.listFactors(token),
        ]);
        return {
            mfaEnabled: enabled,
            currentLevel: level.currentLevel,
            nextLevel: level.nextLevel,
            factors,
        };
    }
    extractToken(req) {
        const authHeader = req.headers.authorization;
        return authHeader?.replace('Bearer ', '') || '';
    }
};
exports.MfaController = MfaController;
__decorate([
    (0, common_1.Post)('enroll'),
    (0, swagger_1.ApiOperation)({
        summary: 'Iniciar enrolamiento de 2FA',
        description: 'Genera un QR code y secret para configurar en tu app de autenticación',
    }),
    (0, swagger_1.ApiResponse)({
        status: 200,
        description: 'QR code y secret generados',
        schema: {
            properties: {
                factorId: { type: 'string' },
                qrCode: { type: 'string', description: 'Base64 del QR code' },
                secret: { type: 'string', description: 'Secret para configurar manualmente' },
                uri: { type: 'string', description: 'URI para apps de autenticación' },
            },
        },
    }),
    openapi.ApiResponse({ status: 201, type: Object }),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], MfaController.prototype, "enrollMfa", null);
__decorate([
    (0, common_1.Post)('verify'),
    (0, swagger_1.ApiOperation)({
        summary: 'Verificar y activar 2FA',
        description: 'Verifica el código TOTP y activa 2FA para la cuenta',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: '2FA activado exitosamente' }),
    (0, swagger_1.ApiResponse)({ status: 401, description: 'Código inválido' }),
    openapi.ApiResponse({ status: 201 }),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, mfa_dto_1.VerifyMfaDto]),
    __metadata("design:returntype", Promise)
], MfaController.prototype, "verifyMfa", null);
__decorate([
    (0, common_1.Get)('factors'),
    (0, swagger_1.ApiOperation)({
        summary: 'Listar factores MFA configurados',
        description: 'Obtiene la lista de métodos 2FA configurados para el usuario',
    }),
    (0, swagger_1.ApiResponse)({
        status: 200,
        description: 'Lista de factores',
        schema: {
            type: 'array',
            items: {
                properties: {
                    id: { type: 'string' },
                    friendlyName: { type: 'string' },
                    factorType: { type: 'string' },
                    status: { type: 'string' },
                    createdAt: { type: 'string' },
                },
            },
        },
    }),
    openapi.ApiResponse({ status: 200, type: [Object] }),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], MfaController.prototype, "listFactors", null);
__decorate([
    (0, common_1.Delete)('unenroll'),
    (0, swagger_1.ApiOperation)({
        summary: 'Deshabilitar 2FA',
        description: 'Elimina un factor MFA de la cuenta',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: '2FA deshabilitado' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, mfa_dto_1.UnenrollMfaDto]),
    __metadata("design:returntype", Promise)
], MfaController.prototype, "unenrollMfa", null);
__decorate([
    (0, common_1.Get)('status'),
    (0, swagger_1.ApiOperation)({
        summary: 'Verificar estado de 2FA',
        description: 'Indica si el usuario tiene 2FA habilitado y su nivel de autenticación',
    }),
    (0, swagger_1.ApiResponse)({
        status: 200,
        schema: {
            properties: {
                mfaEnabled: { type: 'boolean' },
                currentLevel: { type: 'string', description: 'aal1 = password, aal2 = password + MFA' },
                factors: { type: 'array' },
            },
        },
    }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], MfaController.prototype, "getMfaStatus", null);
exports.MfaController = MfaController = __decorate([
    (0, swagger_1.ApiTags)('auth'),
    (0, common_1.Controller)('auth/mfa'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, swagger_1.ApiBearerAuth)(),
    __metadata("design:paramtypes", [mfa_service_1.MfaService])
], MfaController);
//# sourceMappingURL=mfa.controller.js.map