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
exports.UserClassesController = exports.ClassesController = void 0;
const openapi = require("@nestjs/swagger");
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const classes_service_1 = require("./classes.service");
const dto_1 = require("./dto");
const jwt_auth_guard_1 = require("../common/guards/jwt-auth.guard");
const pagination_dto_1 = require("../common/dto/pagination.dto");
let ClassesController = class ClassesController {
    classesService;
    constructor(classesService) {
        this.classesService = classesService;
    }
    async findAll(clubTypeId, page, limit) {
        const pagination = new pagination_dto_1.PaginationDto();
        if (page)
            pagination.page = page;
        if (limit)
            pagination.limit = Math.min(limit, 100);
        return this.classesService.findAll(clubTypeId, pagination);
    }
    async findOne(classId) {
        return this.classesService.findOne(classId);
    }
    async getModules(classId) {
        return this.classesService.getModules(classId);
    }
};
exports.ClassesController = ClassesController;
__decorate([
    (0, common_1.Get)(),
    (0, swagger_1.ApiOperation)({
        summary: 'Listar clases',
        description: 'Lista todas las clases activas con paginación, opcionalmente filtradas por tipo de club',
    }),
    (0, swagger_1.ApiQuery)({
        name: 'clubTypeId',
        required: false,
        type: Number,
        description: 'Filtrar por tipo de club (1=Aventureros, 2=Conquistadores, 3=GM)',
    }),
    (0, swagger_1.ApiQuery)({ name: 'page', required: false, type: Number, description: 'Número de página (1-indexed)' }),
    (0, swagger_1.ApiQuery)({ name: 'limit', required: false, type: Number, description: 'Elementos por página (max 100)' }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista paginada de clases' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Query)('clubTypeId', new common_1.ParseIntPipe({ optional: true }))),
    __param(1, (0, common_1.Query)('page', new common_1.ParseIntPipe({ optional: true }))),
    __param(2, (0, common_1.Query)('limit', new common_1.ParseIntPipe({ optional: true }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Number, Number]),
    __metadata("design:returntype", Promise)
], ClassesController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)(':classId'),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener clase por ID',
        description: 'Retorna la clase con todos sus módulos y secciones',
    }),
    (0, swagger_1.ApiParam)({ name: 'classId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Clase encontrada' }),
    (0, swagger_1.ApiResponse)({ status: 404, description: 'Clase no encontrada' }),
    openapi.ApiResponse({ status: 200, type: Object }),
    __param(0, (0, common_1.Param)('classId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ClassesController.prototype, "findOne", null);
__decorate([
    (0, common_1.Get)(':classId/modules'),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener módulos de una clase',
        description: 'Lista los módulos con sus secciones',
    }),
    (0, swagger_1.ApiParam)({ name: 'classId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Módulos de la clase' }),
    openapi.ApiResponse({ status: 200, type: [Object] }),
    __param(0, (0, common_1.Param)('classId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ClassesController.prototype, "getModules", null);
exports.ClassesController = ClassesController = __decorate([
    (0, swagger_1.ApiTags)('classes'),
    (0, common_1.Controller)('classes'),
    __metadata("design:paramtypes", [classes_service_1.ClassesService])
], ClassesController);
let UserClassesController = class UserClassesController {
    classesService;
    constructor(classesService) {
        this.classesService = classesService;
    }
    async getEnrollments(userId, yearId) {
        return this.classesService.getUserEnrollments(userId, yearId);
    }
    async enroll(userId, dto) {
        return this.classesService.enrollUser(userId, dto.class_id, dto.ecclesiastical_year_id);
    }
    async getProgress(userId, classId) {
        return this.classesService.getUserProgress(userId, classId);
    }
    async updateProgress(userId, classId, dto) {
        return this.classesService.updateSectionProgress(userId, classId, dto.module_id, dto.section_id, dto.score, dto.evidences);
    }
};
exports.UserClassesController = UserClassesController;
__decorate([
    (0, common_1.Get)(),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener inscripciones del usuario',
        description: 'Lista las clases en las que está inscrito el usuario',
    }),
    (0, swagger_1.ApiParam)({ name: 'userId', type: String }),
    (0, swagger_1.ApiQuery)({
        name: 'yearId',
        required: false,
        type: Number,
        description: 'Filtrar por año eclesiástico',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Inscripciones del usuario' }),
    openapi.ApiResponse({ status: 200, type: [Object] }),
    __param(0, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Query)('yearId', new common_1.ParseIntPipe({ optional: true }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Number]),
    __metadata("design:returntype", Promise)
], UserClassesController.prototype, "getEnrollments", null);
__decorate([
    (0, common_1.Post)('enroll'),
    (0, swagger_1.ApiOperation)({
        summary: 'Inscribir usuario en clase',
        description: 'Inscribe al usuario en una clase para el año eclesiástico',
    }),
    (0, swagger_1.ApiParam)({ name: 'userId', type: String }),
    (0, swagger_1.ApiResponse)({ status: 201, description: 'Inscripción creada' }),
    openapi.ApiResponse({ status: 201 }),
    __param(0, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, dto_1.EnrollClassDto]),
    __metadata("design:returntype", Promise)
], UserClassesController.prototype, "enroll", null);
__decorate([
    (0, common_1.Get)(':classId/progress'),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener progreso del usuario en una clase',
        description: 'Retorna el progreso detallado por módulo y sección',
    }),
    (0, swagger_1.ApiParam)({ name: 'userId', type: String }),
    (0, swagger_1.ApiParam)({ name: 'classId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Progreso del usuario' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Param)('classId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Number]),
    __metadata("design:returntype", Promise)
], UserClassesController.prototype, "getProgress", null);
__decorate([
    (0, common_1.Patch)(':classId/progress'),
    (0, swagger_1.ApiOperation)({
        summary: 'Actualizar progreso de sección',
        description: 'Actualiza el puntaje y evidencias de una sección específica',
    }),
    (0, swagger_1.ApiParam)({ name: 'userId', type: String }),
    (0, swagger_1.ApiParam)({ name: 'classId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Progreso actualizado' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Param)('classId', common_1.ParseIntPipe)),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Number, dto_1.UpdateProgressDto]),
    __metadata("design:returntype", Promise)
], UserClassesController.prototype, "updateProgress", null);
exports.UserClassesController = UserClassesController = __decorate([
    (0, swagger_1.ApiTags)('user-classes'),
    (0, common_1.Controller)('users/:userId/classes'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, swagger_1.ApiBearerAuth)(),
    __metadata("design:paramtypes", [classes_service_1.ClassesService])
], UserClassesController);
//# sourceMappingURL=classes.controller.js.map