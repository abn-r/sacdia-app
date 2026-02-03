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
exports.ActivitiesController = void 0;
const openapi = require("@nestjs/swagger");
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const activities_service_1 = require("./activities.service");
const dto_1 = require("./dto");
const guards_1 = require("../common/guards");
const decorators_1 = require("../common/decorators");
const pagination_dto_1 = require("../common/dto/pagination.dto");
let ActivitiesController = class ActivitiesController {
    activitiesService;
    constructor(activitiesService) {
        this.activitiesService = activitiesService;
    }
    async findByClub(clubId, clubTypeId, active, activityType, page, limit) {
        const pagination = new pagination_dto_1.PaginationDto();
        if (page)
            pagination.page = page;
        if (limit)
            pagination.limit = Math.min(limit, 100);
        return this.activitiesService.findByClub(clubId, {
            clubTypeId,
            active: active === 'true' ? true : active === 'false' ? false : undefined,
            activityType,
        }, pagination);
    }
    async create(clubId, dto, req) {
        return this.activitiesService.create(dto, req.user.sub);
    }
    async findOne(activityId) {
        return this.activitiesService.findOne(activityId);
    }
    async update(activityId, dto) {
        return this.activitiesService.update(activityId, dto);
    }
    async remove(activityId) {
        return this.activitiesService.remove(activityId);
    }
    async recordAttendance(activityId, dto) {
        return this.activitiesService.recordAttendance(activityId, dto);
    }
    async getAttendance(activityId) {
        return this.activitiesService.getAttendance(activityId);
    }
};
exports.ActivitiesController = ActivitiesController;
__decorate([
    (0, common_1.Get)('clubs/:clubId/activities'),
    (0, swagger_1.ApiOperation)({
        summary: 'Listar actividades del club',
        description: 'Obtiene todas las actividades de las instancias del club',
    }),
    (0, swagger_1.ApiParam)({ name: 'clubId', type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'clubTypeId', required: false, type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'active', required: false, type: Boolean }),
    (0, swagger_1.ApiQuery)({ name: 'activityType', required: false, type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'page', required: false, type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'limit', required: false, type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista paginada de actividades' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('clubId', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Query)('clubTypeId', new common_1.ParseIntPipe({ optional: true }))),
    __param(2, (0, common_1.Query)('active')),
    __param(3, (0, common_1.Query)('activityType', new common_1.ParseIntPipe({ optional: true }))),
    __param(4, (0, common_1.Query)('page', new common_1.ParseIntPipe({ optional: true }))),
    __param(5, (0, common_1.Query)('limit', new common_1.ParseIntPipe({ optional: true }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Number, String, Number, Number, Number]),
    __metadata("design:returntype", Promise)
], ActivitiesController.prototype, "findByClub", null);
__decorate([
    (0, common_1.Post)('clubs/:clubId/activities'),
    (0, common_1.UseGuards)(guards_1.ClubRolesGuard),
    (0, decorators_1.ClubRoles)('director', 'subdirector', 'secretary', 'counselor'),
    (0, swagger_1.ApiOperation)({
        summary: 'Crear actividad',
        description: 'Crea una nueva actividad para el club (requiere rol de liderazgo)',
    }),
    (0, swagger_1.ApiParam)({ name: 'clubId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 201, description: 'Actividad creada' }),
    (0, swagger_1.ApiResponse)({ status: 403, description: 'Permisos insuficientes' }),
    openapi.ApiResponse({ status: 201, type: Object }),
    __param(0, (0, common_1.Param)('clubId', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, dto_1.CreateActivityDto, Object]),
    __metadata("design:returntype", Promise)
], ActivitiesController.prototype, "create", null);
__decorate([
    (0, common_1.Get)('activities/:activityId'),
    (0, swagger_1.ApiOperation)({ summary: 'Obtener actividad por ID' }),
    (0, swagger_1.ApiParam)({ name: 'activityId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Actividad encontrada' }),
    (0, swagger_1.ApiResponse)({ status: 404, description: 'Actividad no encontrada' }),
    openapi.ApiResponse({ status: 200, type: Object }),
    __param(0, (0, common_1.Param)('activityId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ActivitiesController.prototype, "findOne", null);
__decorate([
    (0, common_1.Patch)('activities/:activityId'),
    (0, swagger_1.ApiOperation)({ summary: 'Actualizar actividad' }),
    (0, swagger_1.ApiParam)({ name: 'activityId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Actividad actualizada' }),
    openapi.ApiResponse({ status: 200, type: Object }),
    __param(0, (0, common_1.Param)('activityId', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, dto_1.UpdateActivityDto]),
    __metadata("design:returntype", Promise)
], ActivitiesController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)('activities/:activityId'),
    (0, swagger_1.ApiOperation)({ summary: 'Desactivar actividad' }),
    (0, swagger_1.ApiParam)({ name: 'activityId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Actividad desactivada' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('activityId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ActivitiesController.prototype, "remove", null);
__decorate([
    (0, common_1.Post)('activities/:activityId/attendance'),
    (0, swagger_1.ApiOperation)({
        summary: 'Registrar asistencia',
        description: 'Registra la lista de usuarios que asistieron a la actividad',
    }),
    (0, swagger_1.ApiParam)({ name: 'activityId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 201, description: 'Asistencia registrada' }),
    openapi.ApiResponse({ status: 201 }),
    __param(0, (0, common_1.Param)('activityId', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, dto_1.RecordAttendanceDto]),
    __metadata("design:returntype", Promise)
], ActivitiesController.prototype, "recordAttendance", null);
__decorate([
    (0, common_1.Get)('activities/:activityId/attendance'),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener asistencia',
        description: 'Obtiene la lista de usuarios que asistieron a la actividad',
    }),
    (0, swagger_1.ApiParam)({ name: 'activityId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista de asistentes' }),
    openapi.ApiResponse({ status: 200, type: Object }),
    __param(0, (0, common_1.Param)('activityId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ActivitiesController.prototype, "getAttendance", null);
exports.ActivitiesController = ActivitiesController = __decorate([
    (0, swagger_1.ApiTags)('activities'),
    (0, common_1.Controller)(),
    (0, common_1.UseGuards)(guards_1.JwtAuthGuard),
    (0, swagger_1.ApiBearerAuth)(),
    __metadata("design:paramtypes", [activities_service_1.ActivitiesService])
], ActivitiesController);
//# sourceMappingURL=activities.controller.js.map