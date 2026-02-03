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
exports.SessionsController = void 0;
const openapi = require("@nestjs/swagger");
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const jwt_auth_guard_1 = require("../common/guards/jwt-auth.guard");
const session_management_service_1 = require("../common/services/session-management.service");
const token_blacklist_service_1 = require("../common/services/token-blacklist.service");
let SessionsController = class SessionsController {
    sessionService;
    tokenBlacklistService;
    constructor(sessionService, tokenBlacklistService) {
        this.sessionService = sessionService;
        this.tokenBlacklistService = tokenBlacklistService;
    }
    async listSessions(req) {
        const userId = req.user?.user_id;
        return this.sessionService.getSessionStats(userId);
    }
    async closeSession(req, sessionId) {
        const userId = req.user?.user_id;
        await this.sessionService.removeSession(userId, sessionId);
        return { success: true, message: 'Session closed' };
    }
    async closeAllSessions(req) {
        const userId = req.user?.user_id;
        await this.tokenBlacklistService.blacklistAllUserTokens(userId);
        const count = await this.sessionService.removeAllSessions(userId);
        return {
            success: true,
            message: `${count} sessions closed. Please login again.`,
        };
    }
};
exports.SessionsController = SessionsController;
__decorate([
    (0, common_1.Get)(),
    (0, swagger_1.ApiOperation)({
        summary: 'Listar sesiones activas',
        description: 'Obtiene todas las sesiones activas del usuario actual',
    }),
    (0, swagger_1.ApiResponse)({
        status: 200,
        description: 'Lista de sesiones',
        schema: {
            properties: {
                activeSessions: { type: 'number' },
                maxSessions: { type: 'number' },
                sessions: {
                    type: 'array',
                    items: {
                        properties: {
                            sessionId: { type: 'string' },
                            deviceInfo: { type: 'string' },
                            ipAddress: { type: 'string' },
                            createdAt: { type: 'string' },
                            lastActivity: { type: 'string' },
                        },
                    },
                },
            },
        },
    }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], SessionsController.prototype, "listSessions", null);
__decorate([
    (0, common_1.Delete)(':sessionId'),
    (0, swagger_1.ApiOperation)({
        summary: 'Cerrar una sesión específica',
        description: 'Cierra una sesión en otro dispositivo',
    }),
    (0, swagger_1.ApiParam)({ name: 'sessionId', description: 'ID de la sesión a cerrar' }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Sesión cerrada' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('sessionId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], SessionsController.prototype, "closeSession", null);
__decorate([
    (0, common_1.Delete)(),
    (0, swagger_1.ApiOperation)({
        summary: 'Cerrar todas las sesiones',
        description: 'Cierra todas las sesiones excepto la actual (logout de todos los dispositivos)',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Todas las sesiones cerradas' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], SessionsController.prototype, "closeAllSessions", null);
exports.SessionsController = SessionsController = __decorate([
    (0, swagger_1.ApiTags)('auth'),
    (0, common_1.Controller)('auth/sessions'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, swagger_1.ApiBearerAuth)(),
    __metadata("design:paramtypes", [session_management_service_1.SessionManagementService,
        token_blacklist_service_1.TokenBlacklistService])
], SessionsController);
//# sourceMappingURL=sessions.controller.js.map