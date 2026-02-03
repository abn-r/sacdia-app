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
exports.FinancesController = void 0;
const openapi = require("@nestjs/swagger");
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const finances_service_1 = require("./finances.service");
const dto_1 = require("./dto");
const guards_1 = require("../common/guards");
const decorators_1 = require("../common/decorators");
const pagination_dto_1 = require("../common/dto/pagination.dto");
let FinancesController = class FinancesController {
    financesService;
    constructor(financesService) {
        this.financesService = financesService;
    }
    async getCategories(type) {
        return this.financesService.getCategories(type);
    }
    async findByClub(clubId, year, month, clubTypeId, categoryId, page, limit) {
        const pagination = new pagination_dto_1.PaginationDto();
        if (page)
            pagination.page = page;
        if (limit)
            pagination.limit = Math.min(limit, 100);
        return this.financesService.findByClub(clubId, { year, month, clubTypeId, categoryId }, pagination);
    }
    async getSummary(clubId, year, month) {
        return this.financesService.getSummary(clubId, year, month);
    }
    async create(clubId, dto, req) {
        return this.financesService.create(dto, req.user.sub);
    }
    async findOne(financeId) {
        return this.financesService.findOne(financeId);
    }
    async update(financeId, dto) {
        return this.financesService.update(financeId, dto);
    }
    async remove(financeId) {
        return this.financesService.remove(financeId);
    }
};
exports.FinancesController = FinancesController;
__decorate([
    (0, common_1.Get)('finances/categories'),
    (0, swagger_1.ApiOperation)({
        summary: 'Listar categorías financieras',
        description: 'Lista todas las categorías de ingresos y egresos',
    }),
    (0, swagger_1.ApiQuery)({
        name: 'type',
        required: false,
        type: Number,
        description: '0=Ingresos, 1=Egresos',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista de categorías' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Query)('type', new common_1.ParseIntPipe({ optional: true }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], FinancesController.prototype, "getCategories", null);
__decorate([
    (0, common_1.Get)('clubs/:clubId/finances'),
    (0, swagger_1.ApiOperation)({
        summary: 'Listar movimientos financieros del club',
        description: 'Obtiene todos los movimientos de las instancias del club',
    }),
    (0, swagger_1.ApiParam)({ name: 'clubId', type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'year', required: false, type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'month', required: false, type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'clubTypeId', required: false, type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'categoryId', required: false, type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'page', required: false, type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'limit', required: false, type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista paginada de movimientos' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('clubId', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Query)('year', new common_1.ParseIntPipe({ optional: true }))),
    __param(2, (0, common_1.Query)('month', new common_1.ParseIntPipe({ optional: true }))),
    __param(3, (0, common_1.Query)('clubTypeId', new common_1.ParseIntPipe({ optional: true }))),
    __param(4, (0, common_1.Query)('categoryId', new common_1.ParseIntPipe({ optional: true }))),
    __param(5, (0, common_1.Query)('page', new common_1.ParseIntPipe({ optional: true }))),
    __param(6, (0, common_1.Query)('limit', new common_1.ParseIntPipe({ optional: true }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Number, Number, Number, Number, Number, Number]),
    __metadata("design:returntype", Promise)
], FinancesController.prototype, "findByClub", null);
__decorate([
    (0, common_1.Get)('clubs/:clubId/finances/summary'),
    (0, swagger_1.ApiOperation)({
        summary: 'Resumen financiero del club',
        description: 'Obtiene el resumen de ingresos, egresos y balance',
    }),
    (0, swagger_1.ApiParam)({ name: 'clubId', type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'year', required: false, type: Number }),
    (0, swagger_1.ApiQuery)({ name: 'month', required: false, type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Resumen financiero' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('clubId', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Query)('year', new common_1.ParseIntPipe({ optional: true }))),
    __param(2, (0, common_1.Query)('month', new common_1.ParseIntPipe({ optional: true }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Number, Number]),
    __metadata("design:returntype", Promise)
], FinancesController.prototype, "getSummary", null);
__decorate([
    (0, common_1.Post)('clubs/:clubId/finances'),
    (0, common_1.UseGuards)(guards_1.ClubRolesGuard),
    (0, decorators_1.ClubRoles)('director', 'subdirector', 'treasurer'),
    (0, swagger_1.ApiOperation)({
        summary: 'Crear movimiento financiero',
        description: 'Crea un nuevo ingreso o egreso (requiere rol de tesorería)',
    }),
    (0, swagger_1.ApiParam)({ name: 'clubId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 201, description: 'Movimiento creado' }),
    (0, swagger_1.ApiResponse)({ status: 403, description: 'Permisos insuficientes' }),
    openapi.ApiResponse({ status: 201, type: Object }),
    __param(0, (0, common_1.Param)('clubId', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Request)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, dto_1.CreateFinanceDto, Object]),
    __metadata("design:returntype", Promise)
], FinancesController.prototype, "create", null);
__decorate([
    (0, common_1.Get)('finances/:financeId'),
    (0, swagger_1.ApiOperation)({ summary: 'Obtener movimiento por ID' }),
    (0, swagger_1.ApiParam)({ name: 'financeId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Movimiento encontrado' }),
    (0, swagger_1.ApiResponse)({ status: 404, description: 'Movimiento no encontrado' }),
    openapi.ApiResponse({ status: 200, type: Object }),
    __param(0, (0, common_1.Param)('financeId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], FinancesController.prototype, "findOne", null);
__decorate([
    (0, common_1.Patch)('finances/:financeId'),
    (0, swagger_1.ApiOperation)({ summary: 'Actualizar movimiento' }),
    (0, swagger_1.ApiParam)({ name: 'financeId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Movimiento actualizado' }),
    openapi.ApiResponse({ status: 200, type: Object }),
    __param(0, (0, common_1.Param)('financeId', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, dto_1.UpdateFinanceDto]),
    __metadata("design:returntype", Promise)
], FinancesController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)('finances/:financeId'),
    (0, swagger_1.ApiOperation)({ summary: 'Desactivar movimiento' }),
    (0, swagger_1.ApiParam)({ name: 'financeId', type: Number }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Movimiento desactivado' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('financeId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], FinancesController.prototype, "remove", null);
exports.FinancesController = FinancesController = __decorate([
    (0, swagger_1.ApiTags)('finances'),
    (0, common_1.Controller)(),
    (0, common_1.UseGuards)(guards_1.JwtAuthGuard),
    (0, swagger_1.ApiBearerAuth)(),
    __metadata("design:paramtypes", [finances_service_1.FinancesService])
], FinancesController);
//# sourceMappingURL=finances.controller.js.map