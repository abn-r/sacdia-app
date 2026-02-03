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
exports.ClubRolesController = exports.ClubsController = void 0;
const openapi = require("@nestjs/swagger");
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const clubs_service_1 = require("./clubs.service");
const dto_1 = require("./dto");
const guards_1 = require("../common/guards");
const decorators_1 = require("../common/decorators");
const pagination_dto_1 = require("../common/dto/pagination.dto");
let ClubsController = class ClubsController {
    clubsService;
    constructor(clubsService) {
        this.clubsService = clubsService;
    }
    async findAll(localFieldId, districtId, churchId, active, page, limit) {
        const pagination = new pagination_dto_1.PaginationDto();
        if (page)
            pagination.page = page;
        if (limit)
            pagination.limit = Math.min(limit, 100);
        return this.clubsService.findAll({
            localFieldId,
            districtId,
            churchId,
            active: active === 'true' ? true : active === 'false' ? false : undefined,
        }, pagination);
    }
    async findOne(clubId) {
        return this.clubsService.findOne(clubId);
    }
    async create(dto) {
        return this.clubsService.create(dto);
    }
    async update(clubId, dto) {
        return this.clubsService.update(clubId, dto);
    }
    async remove(clubId) {
        return this.clubsService.remove(clubId);
    }
    async getInstances(clubId) {
        return this.clubsService.getInstances(clubId);
    }
    async getInstance(clubId, type) {
        return this.clubsService.getInstance(clubId, type);
    }
    async createInstance(clubId, dto) {
        return this.clubsService.createInstance(clubId, dto);
    }
    async updateInstance(instanceId, type, dto) {
        return this.clubsService.updateInstance(instanceId, type, dto);
    }
    async getMembers(instanceId, type) {
        return this.clubsService.getMembers(instanceId, type);
    }
    async assignRole(dto) {
        return this.clubsService.assignRole(dto);
    }
};
exports.ClubsController = ClubsController;
__decorate([
    (0, common_1.Get)(),
    (0, swagger_1.ApiOperation)({
        summary: 'Listar clubs',
        description: 'Obtiene la lista de clubs con filtros opcionales y paginación',
    }),
    (0, swagger_1.ApiQuery)({ name: 'localFieldId', required: false, type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'districtId', required: false, type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'churchId', required: false, type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'active', required: false, type: Boolean }),
    (0, swagger_1.ApiQuery)({ name: 'page', required: false, type: Number, description: 'Número de página (1-indexed)' }),
    (0, swagger_1.ApiQuery)({ name: 'limit', required: false, type: Number, description: 'Elementos por página (max 100)' }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista paginada de clubs' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Query)('localFieldId', new common_1.ParseIntPipe({ optional: true }))),
    __param(1, (0, common_1.Query)('districtId', new common_1.ParseIntPipe({ optional: true }))),
    __param(2, (0, common_1.Query)('churchId', new common_1.ParseIntPipe({ optional: true }))),
    __param(3, (0, common_1.Query)('active')),
    __param(4, (0, common_1.Query)('page', new common_1.ParseIntPipe({ optional: true }))),
    __param(5, (0, common_1.Query)('limit', new common_1.ParseIntPipe({ optional: true }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Number, Number, String, Number, Number]),
    __metadata("design:returntype", Promise)
], ClubsController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)(':clubId'),
    (0, swagger_1.ApiOperation)({ summary: 'Obtener club por ID' }),
    (0, swagger_1.ApiParam)({ name: 'clubId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Club encontrado' }),
    (0, swagger_1.ApiResponse)({ status: 404, description: 'Club no encontrado' }),
    openapi.ApiResponse({ status: 200, type: Object }),
    __param(0, (0, common_1.Param)('clubId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ClubsController.prototype, "findOne", null);
__decorate([
    (0, common_1.Post)(),
    (0, swagger_1.ApiOperation)({ summary: 'Crear nuevo club' }),
    (0, swagger_1.ApiResponse)({ status: 201, description: 'Club creado' }),
    openapi.ApiResponse({ status: 201 }),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [dto_1.CreateClubDto]),
    __metadata("design:returntype", Promise)
], ClubsController.prototype, "create", null);
__decorate([
    (0, common_1.Patch)(':clubId'),
    (0, common_1.UseGuards)(guards_1.ClubRolesGuard),
    (0, decorators_1.ClubRoles)('director', 'subdirector'),
    (0, swagger_1.ApiOperation)({ summary: 'Actualizar club (requiere rol director o subdirector)' }),
    (0, swagger_1.ApiParam)({ name: 'clubId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Club actualizado' }),
    (0, swagger_1.ApiResponse)({ status: 403, description: 'Permisos insuficientes' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('clubId', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, dto_1.UpdateClubDto]),
    __metadata("design:returntype", Promise)
], ClubsController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':clubId'),
    (0, common_1.UseGuards)(guards_1.ClubRolesGuard),
    (0, decorators_1.ClubRoles)('director'),
    (0, swagger_1.ApiOperation)({ summary: 'Desactivar club (requiere rol director)' }),
    (0, swagger_1.ApiParam)({ name: 'clubId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Club desactivado' }),
    (0, swagger_1.ApiResponse)({ status: 403, description: 'Permisos insuficientes' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('clubId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ClubsController.prototype, "remove", null);
__decorate([
    (0, common_1.Get)(':clubId/instances'),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener instancias del club',
        description: 'Lista todas las instancias (Aventureros, Conquistadores, GM)',
    }),
    (0, swagger_1.ApiParam)({ name: 'clubId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Instancias del club' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('clubId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ClubsController.prototype, "getInstances", null);
__decorate([
    (0, common_1.Get)(':clubId/instances/:type'),
    (0, swagger_1.ApiOperation)({ summary: 'Obtener instancia por tipo' }),
    (0, swagger_1.ApiParam)({ name: 'clubId', type: Number }),
    (0, swagger_1.ApiParam)({
        name: 'type',
        enum: dto_1.ClubInstanceType,
        description: 'Tipo de instancia',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Instancia encontrada' }),
    openapi.ApiResponse({ status: 200, type: Object }),
    __param(0, (0, common_1.Param)('clubId', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Param)('type')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, String]),
    __metadata("design:returntype", Promise)
], ClubsController.prototype, "getInstance", null);
__decorate([
    (0, common_1.Post)(':clubId/instances'),
    (0, common_1.UseGuards)(guards_1.ClubRolesGuard),
    (0, decorators_1.ClubRoles)('director', 'subdirector'),
    (0, swagger_1.ApiOperation)({
        summary: 'Crear instancia de club (requiere director o subdirector)',
        description: 'Crea una nueva instancia (Aventureros, Conquistadores, Guías Mayores)',
    }),
    (0, swagger_1.ApiParam)({ name: 'clubId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 201, description: 'Instancia creada' }),
    (0, swagger_1.ApiResponse)({ status: 403, description: 'Permisos insuficientes' }),
    openapi.ApiResponse({ status: 201, type: Object }),
    __param(0, (0, common_1.Param)('clubId', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, dto_1.CreateInstanceDto]),
    __metadata("design:returntype", Promise)
], ClubsController.prototype, "createInstance", null);
__decorate([
    (0, common_1.Patch)(':clubId/instances/:type/:instanceId'),
    (0, common_1.UseGuards)(guards_1.ClubRolesGuard),
    (0, decorators_1.ClubRoles)('director', 'subdirector', 'secretary'),
    (0, swagger_1.ApiOperation)({ summary: 'Actualizar instancia (requiere director, subdirector o secretario)' }),
    (0, swagger_1.ApiParam)({ name: 'clubId', type: Number }),
    (0, swagger_1.ApiParam)({ name: 'type', enum: dto_1.ClubInstanceType }),
    (0, swagger_1.ApiParam)({ name: 'instanceId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Instancia actualizada' }),
    (0, swagger_1.ApiResponse)({ status: 403, description: 'Permisos insuficientes' }),
    openapi.ApiResponse({ status: 200, type: Object }),
    __param(0, (0, common_1.Param)('instanceId', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Param)('type')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, String, dto_1.UpdateInstanceDto]),
    __metadata("design:returntype", Promise)
], ClubsController.prototype, "updateInstance", null);
__decorate([
    (0, common_1.Get)(':clubId/instances/:type/:instanceId/members'),
    (0, swagger_1.ApiOperation)({
        summary: 'Listar miembros de la instancia',
        description: 'Retorna todos los miembros asignados a la instancia con sus roles',
    }),
    (0, swagger_1.ApiParam)({ name: 'clubId', type: Number }),
    (0, swagger_1.ApiParam)({ name: 'type', enum: dto_1.ClubInstanceType }),
    (0, swagger_1.ApiParam)({ name: 'instanceId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista de miembros' }),
    openapi.ApiResponse({ status: 200, type: [Object] }),
    __param(0, (0, common_1.Param)('instanceId', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Param)('type')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, String]),
    __metadata("design:returntype", Promise)
], ClubsController.prototype, "getMembers", null);
__decorate([
    (0, common_1.Post)(':clubId/instances/:type/:instanceId/roles'),
    (0, common_1.UseGuards)(guards_1.ClubRolesGuard),
    (0, decorators_1.ClubRoles)('director', 'subdirector', 'secretary'),
    (0, swagger_1.ApiOperation)({
        summary: 'Asignar rol a un miembro (requiere director, subdirector o secretario)',
        description: 'Asigna un rol específico a un usuario en la instancia',
    }),
    (0, swagger_1.ApiParam)({ name: 'clubId', type: Number }),
    (0, swagger_1.ApiParam)({ name: 'type', enum: dto_1.ClubInstanceType }),
    (0, swagger_1.ApiParam)({ name: 'instanceId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 201, description: 'Rol asignado' }),
    (0, swagger_1.ApiResponse)({ status: 403, description: 'Permisos insuficientes' }),
    openapi.ApiResponse({ status: 201, type: Object }),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [dto_1.AssignRoleDto]),
    __metadata("design:returntype", Promise)
], ClubsController.prototype, "assignRole", null);
exports.ClubsController = ClubsController = __decorate([
    (0, swagger_1.ApiTags)('clubs'),
    (0, common_1.Controller)('clubs'),
    (0, common_1.UseGuards)(guards_1.JwtAuthGuard),
    (0, swagger_1.ApiBearerAuth)(),
    __metadata("design:paramtypes", [clubs_service_1.ClubsService])
], ClubsController);
let ClubRolesController = class ClubRolesController {
    clubsService;
    constructor(clubsService) {
        this.clubsService = clubsService;
    }
    async updateAssignment(assignmentId, dto) {
        return this.clubsService.updateRoleAssignment(assignmentId, dto);
    }
    async removeAssignment(assignmentId) {
        return this.clubsService.removeRoleAssignment(assignmentId);
    }
};
exports.ClubRolesController = ClubRolesController;
__decorate([
    (0, common_1.Patch)(':assignmentId'),
    (0, swagger_1.ApiOperation)({ summary: 'Actualizar asignación de rol' }),
    (0, swagger_1.ApiParam)({ name: 'assignmentId', type: String }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Asignación actualizada' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('assignmentId')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, dto_1.UpdateRoleAssignmentDto]),
    __metadata("design:returntype", Promise)
], ClubRolesController.prototype, "updateAssignment", null);
__decorate([
    (0, common_1.Delete)(':assignmentId'),
    (0, swagger_1.ApiOperation)({ summary: 'Remover rol de miembro' }),
    (0, swagger_1.ApiParam)({ name: 'assignmentId', type: String }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Rol removido' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('assignmentId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], ClubRolesController.prototype, "removeAssignment", null);
exports.ClubRolesController = ClubRolesController = __decorate([
    (0, swagger_1.ApiTags)('club-roles'),
    (0, common_1.Controller)('club-roles'),
    (0, common_1.UseGuards)(guards_1.JwtAuthGuard),
    (0, swagger_1.ApiBearerAuth)(),
    __metadata("design:paramtypes", [clubs_service_1.ClubsService])
], ClubRolesController);
//# sourceMappingURL=clubs.controller.js.map