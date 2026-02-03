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
exports.UserHonorsController = exports.HonorsController = void 0;
const openapi = require("@nestjs/swagger");
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const honors_service_1 = require("./honors.service");
const dto_1 = require("./dto");
const jwt_auth_guard_1 = require("../common/guards/jwt-auth.guard");
const pagination_dto_1 = require("../common/dto/pagination.dto");
let HonorsController = class HonorsController {
    honorsService;
    constructor(honorsService) {
        this.honorsService = honorsService;
    }
    async findAll(categoryId, clubTypeId, skillLevel, page, limit) {
        const pagination = new pagination_dto_1.PaginationDto();
        if (page)
            pagination.page = page;
        if (limit)
            pagination.limit = Math.min(limit, 100);
        return this.honorsService.findAll({ categoryId, clubTypeId, skillLevel }, pagination);
    }
    async getCategories() {
        return this.honorsService.getCategories();
    }
    async findOne(honorId) {
        return this.honorsService.findOne(honorId);
    }
};
exports.HonorsController = HonorsController;
__decorate([
    (0, common_1.Get)(),
    (0, swagger_1.ApiOperation)({
        summary: 'Listar honores',
        description: 'Lista todos los honores activos con paginación y filtros',
    }),
    (0, swagger_1.ApiQuery)({ name: 'categoryId', required: false, type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'clubTypeId', required: false, type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'skillLevel', required: false, type: Number, description: '1=Básico, 2=Avanzado, 3=Máster' }),
    (0, swagger_1.ApiQuery)({ name: 'page', required: false, type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'limit', required: false, type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista paginada de honores' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Query)('categoryId', new common_1.ParseIntPipe({ optional: true }))),
    __param(1, (0, common_1.Query)('clubTypeId', new common_1.ParseIntPipe({ optional: true }))),
    __param(2, (0, common_1.Query)('skillLevel', new common_1.ParseIntPipe({ optional: true }))),
    __param(3, (0, common_1.Query)('page', new common_1.ParseIntPipe({ optional: true }))),
    __param(4, (0, common_1.Query)('limit', new common_1.ParseIntPipe({ optional: true }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Number, Number, Number, Number]),
    __metadata("design:returntype", Promise)
], HonorsController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)('categories'),
    (0, swagger_1.ApiOperation)({ summary: 'Listar categorías de honores' }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista de categorías' }),
    openapi.ApiResponse({ status: 200 }),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], HonorsController.prototype, "getCategories", null);
__decorate([
    (0, common_1.Get)(':honorId'),
    (0, swagger_1.ApiOperation)({ summary: 'Obtener honor por ID' }),
    (0, swagger_1.ApiParam)({ name: 'honorId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Honor encontrado' }),
    (0, swagger_1.ApiResponse)({ status: 404, description: 'Honor no encontrado' }),
    openapi.ApiResponse({ status: 200, type: Object }),
    __param(0, (0, common_1.Param)('honorId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], HonorsController.prototype, "findOne", null);
exports.HonorsController = HonorsController = __decorate([
    (0, swagger_1.ApiTags)('honors'),
    (0, common_1.Controller)('honors'),
    __metadata("design:paramtypes", [honors_service_1.HonorsService])
], HonorsController);
let UserHonorsController = class UserHonorsController {
    honorsService;
    constructor(honorsService) {
        this.honorsService = honorsService;
    }
    async getUserHonors(userId, validated) {
        const validatedBool = validated === 'true' ? true : validated === 'false' ? false : undefined;
        return this.honorsService.getUserHonors(userId, validatedBool);
    }
    async getStats(userId) {
        return this.honorsService.getUserHonorStats(userId);
    }
    async startHonor(userId, honorId, dto) {
        return this.honorsService.startHonor(userId, honorId, dto);
    }
    async updateHonor(userId, honorId, dto) {
        return this.honorsService.updateUserHonor(userId, honorId, dto);
    }
    async abandonHonor(userId, honorId) {
        return this.honorsService.abandonHonor(userId, honorId);
    }
};
exports.UserHonorsController = UserHonorsController;
__decorate([
    (0, common_1.Get)(),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener honores del usuario',
        description: 'Lista los honores en los que el usuario está inscrito o ha completado',
    }),
    (0, swagger_1.ApiParam)({ name: 'userId', type: String }),
    (0, swagger_1.ApiQuery)({ name: 'validated', required: false, type: Boolean }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Honores del usuario' }),
    openapi.ApiResponse({ status: 200, type: [Object] }),
    __param(0, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Query)('validated')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], UserHonorsController.prototype, "getUserHonors", null);
__decorate([
    (0, common_1.Get)('stats'),
    (0, swagger_1.ApiOperation)({ summary: 'Obtener estadísticas de honores del usuario' }),
    (0, swagger_1.ApiParam)({ name: 'userId', type: String }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Estadísticas de honores' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], UserHonorsController.prototype, "getStats", null);
__decorate([
    (0, common_1.Post)(':honorId'),
    (0, swagger_1.ApiOperation)({
        summary: 'Iniciar un honor',
        description: 'Inscribe al usuario en un honor para comenzar a trabajarlo',
    }),
    (0, swagger_1.ApiParam)({ name: 'userId', type: String }),
    (0, swagger_1.ApiParam)({ name: 'honorId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 201, description: 'Honor iniciado' }),
    (0, swagger_1.ApiResponse)({ status: 409, description: 'Usuario ya tiene este honor' }),
    openapi.ApiResponse({ status: 201, type: Object }),
    __param(0, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Param)('honorId', common_1.ParseIntPipe)),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Number, dto_1.StartHonorDto]),
    __metadata("design:returntype", Promise)
], UserHonorsController.prototype, "startHonor", null);
__decorate([
    (0, common_1.Patch)(':honorId'),
    (0, swagger_1.ApiOperation)({
        summary: 'Actualizar progreso de honor',
        description: 'Actualiza evidencias, validación o certificado del honor',
    }),
    (0, swagger_1.ApiParam)({ name: 'userId', type: String }),
    (0, swagger_1.ApiParam)({ name: 'honorId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Honor actualizado' }),
    openapi.ApiResponse({ status: 200, type: Object }),
    __param(0, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Param)('honorId', common_1.ParseIntPipe)),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Number, dto_1.UpdateUserHonorDto]),
    __metadata("design:returntype", Promise)
], UserHonorsController.prototype, "updateHonor", null);
__decorate([
    (0, common_1.Delete)(':honorId'),
    (0, swagger_1.ApiOperation)({
        summary: 'Abandonar honor',
        description: 'Desactiva el honor del usuario (no lo elimina)',
    }),
    (0, swagger_1.ApiParam)({ name: 'userId', type: String }),
    (0, swagger_1.ApiParam)({ name: 'honorId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Honor abandonado' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Param)('honorId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Number]),
    __metadata("design:returntype", Promise)
], UserHonorsController.prototype, "abandonHonor", null);
exports.UserHonorsController = UserHonorsController = __decorate([
    (0, swagger_1.ApiTags)('user-honors'),
    (0, common_1.Controller)('users/:userId/honors'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, swagger_1.ApiBearerAuth)(),
    __metadata("design:paramtypes", [honors_service_1.HonorsService])
], UserHonorsController);
//# sourceMappingURL=honors.controller.js.map