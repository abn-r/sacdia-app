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
exports.PostRegistrationController = void 0;
const openapi = require("@nestjs/swagger");
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const post_registration_service_1 = require("./post-registration.service");
const complete_club_selection_dto_1 = require("./dto/complete-club-selection.dto");
const jwt_auth_guard_1 = require("../common/guards/jwt-auth.guard");
let PostRegistrationController = class PostRegistrationController {
    postRegistrationService;
    constructor(postRegistrationService) {
        this.postRegistrationService = postRegistrationService;
    }
    async getStatus(userId) {
        return this.postRegistrationService.getStatus(userId);
    }
    async completeStep1(userId) {
        return this.postRegistrationService.completeStep1(userId);
    }
    async completeStep2(userId) {
        return this.postRegistrationService.completeStep2(userId);
    }
    async completeStep3(userId, dto) {
        return this.postRegistrationService.completeStep3(userId, dto);
    }
};
exports.PostRegistrationController = PostRegistrationController;
__decorate([
    (0, common_1.Get)('status'),
    (0, swagger_1.ApiOperation)({ summary: 'Obtener estado del post-registro' }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Estado actual' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], PostRegistrationController.prototype, "getStatus", null);
__decorate([
    (0, common_1.Post)('step-1/complete'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    (0, swagger_1.ApiOperation)({
        summary: 'Completar Paso 1: Foto de perfil',
        description: 'Valida que el usuario tenga foto subida',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Paso 1 completado' }),
    (0, swagger_1.ApiResponse)({
        status: 400,
        description: 'Usuario no tiene foto de perfil',
    }),
    openapi.ApiResponse({ status: common_1.HttpStatus.OK }),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], PostRegistrationController.prototype, "completeStep1", null);
__decorate([
    (0, common_1.Post)('step-2/complete'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    (0, swagger_1.ApiOperation)({
        summary: 'Completar Paso 2: Información personal',
        description: 'Valida: género, cumpleaños, bautismo, >= 1 contacto emergencia, representante legal si < 18',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Paso 2 completado' }),
    (0, swagger_1.ApiResponse)({
        status: 400,
        description: 'Faltan datos requeridos',
    }),
    openapi.ApiResponse({ status: common_1.HttpStatus.OK }),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], PostRegistrationController.prototype, "completeStep2", null);
__decorate([
    (0, common_1.Post)('step-3/complete'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    (0, swagger_1.ApiOperation)({
        summary: 'Completar Paso 3: Selección de club',
        description: 'Transacción completa: actualiza país/unión/campo, asigna rol member, inscribe en clase, marca post-registro completo',
    }),
    (0, swagger_1.ApiResponse)({
        status: 200,
        description: 'Paso 3 completado - POST-REGISTRO COMPLETO',
    }),
    (0, swagger_1.ApiResponse)({
        status: 400,
        description: 'Club no encontrado o datos inválidos',
    }),
    openapi.ApiResponse({ status: common_1.HttpStatus.OK }),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, complete_club_selection_dto_1.CompleteClubSelectionDto]),
    __metadata("design:returntype", Promise)
], PostRegistrationController.prototype, "completeStep3", null);
exports.PostRegistrationController = PostRegistrationController = __decorate([
    (0, swagger_1.ApiTags)('post-registration'),
    (0, common_1.Controller)('users/:userId/post-registration'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, swagger_1.ApiBearerAuth)(),
    __metadata("design:paramtypes", [post_registration_service_1.PostRegistrationService])
], PostRegistrationController);
//# sourceMappingURL=post-registration.controller.js.map