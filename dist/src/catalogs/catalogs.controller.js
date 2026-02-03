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
exports.CatalogsController = void 0;
const openapi = require("@nestjs/swagger");
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const catalogs_service_1 = require("./catalogs.service");
let CatalogsController = class CatalogsController {
    catalogsService;
    constructor(catalogsService) {
        this.catalogsService = catalogsService;
    }
    async getClubTypes() {
        return this.catalogsService.getClubTypes();
    }
    async getCountries() {
        return this.catalogsService.getCountries();
    }
    async getUnions(countryId) {
        return this.catalogsService.getUnions(countryId);
    }
    async getLocalFields(unionId) {
        return this.catalogsService.getLocalFields(unionId);
    }
    async getDistricts(localFieldId) {
        return this.catalogsService.getDistricts(localFieldId);
    }
    async getChurches(districtId) {
        return this.catalogsService.getChurches(districtId);
    }
    async getRoles(category) {
        return this.catalogsService.getRoles(category);
    }
    async getEcclesiasticalYears() {
        return this.catalogsService.getEcclesiasticalYears();
    }
    async getCurrentEcclesiasticalYear() {
        return this.catalogsService.getCurrentEcclesiasticalYear();
    }
    async getClubIdeals(clubTypeId) {
        return this.catalogsService.getClubIdeals(clubTypeId);
    }
};
exports.CatalogsController = CatalogsController;
__decorate([
    (0, common_1.Get)('club-types'),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener tipos de club',
        description: 'Lista los tipos de club disponibles (Aventureros, Conquistadores, Guías Mayores)',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista de tipos de club' }),
    openapi.ApiResponse({ status: 200 }),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], CatalogsController.prototype, "getClubTypes", null);
__decorate([
    (0, common_1.Get)('countries'),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener países',
        description: 'Lista todos los países activos',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista de países' }),
    openapi.ApiResponse({ status: 200 }),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], CatalogsController.prototype, "getCountries", null);
__decorate([
    (0, common_1.Get)('unions'),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener uniones',
        description: 'Lista uniones de la organización, opcionalmente filtradas por país',
    }),
    (0, swagger_1.ApiQuery)({
        name: 'countryId',
        required: false,
        type: Number,
        description: 'ID del país para filtrar',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista de uniones' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Query)('countryId', new common_1.ParseIntPipe({ optional: true }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], CatalogsController.prototype, "getUnions", null);
__decorate([
    (0, common_1.Get)('local-fields'),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener campos locales',
        description: 'Lista campos locales, opcionalmente filtrados por unión',
    }),
    (0, swagger_1.ApiQuery)({
        name: 'unionId',
        required: false,
        type: Number,
        description: 'ID de la unión para filtrar',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista de campos locales' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Query)('unionId', new common_1.ParseIntPipe({ optional: true }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], CatalogsController.prototype, "getLocalFields", null);
__decorate([
    (0, common_1.Get)('districts'),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener distritos',
        description: 'Lista distritos, opcionalmente filtrados por campo local',
    }),
    (0, swagger_1.ApiQuery)({
        name: 'localFieldId',
        required: false,
        type: Number,
        description: 'ID del campo local para filtrar',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista de distritos' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Query)('localFieldId', new common_1.ParseIntPipe({ optional: true }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], CatalogsController.prototype, "getDistricts", null);
__decorate([
    (0, common_1.Get)('churches'),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener iglesias',
        description: 'Lista iglesias, opcionalmente filtradas por distrito',
    }),
    (0, swagger_1.ApiQuery)({
        name: 'districtId',
        required: false,
        type: Number,
        description: 'ID del distrito para filtrar',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista de iglesias' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Query)('districtId', new common_1.ParseIntPipe({ optional: true }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], CatalogsController.prototype, "getChurches", null);
__decorate([
    (0, common_1.Get)('roles'),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener roles disponibles',
        description: 'Lista roles del sistema, opcionalmente filtrados por categoría (GLOBAL o CLUB)',
    }),
    (0, swagger_1.ApiQuery)({
        name: 'category',
        required: false,
        type: String,
        enum: ['GLOBAL', 'CLUB'],
        description: 'Categoría de rol para filtrar',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista de roles' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Query)('category')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], CatalogsController.prototype, "getRoles", null);
__decorate([
    (0, common_1.Get)('ecclesiastical-years'),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener años eclesiásticos',
        description: 'Lista todos los años eclesiásticos registrados',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista de años eclesiásticos' }),
    openapi.ApiResponse({ status: 200 }),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], CatalogsController.prototype, "getEcclesiasticalYears", null);
__decorate([
    (0, common_1.Get)('ecclesiastical-years/current'),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener año eclesiástico actual',
        description: 'Retorna el año eclesiástico vigente basado en la fecha actual',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Año eclesiástico actual' }),
    openapi.ApiResponse({ status: 200, type: Object }),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], CatalogsController.prototype, "getCurrentEcclesiasticalYear", null);
__decorate([
    (0, common_1.Get)('club-ideals'),
    (0, swagger_1.ApiOperation)({
        summary: 'Obtener ideales de club',
        description: 'Lista los ideales (ley, voto, lema, etc.) por tipo de club',
    }),
    (0, swagger_1.ApiQuery)({
        name: 'clubTypeId',
        required: false,
        type: Number,
        description: 'ID del tipo de club para filtrar',
    }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista de ideales' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Query)('clubTypeId', new common_1.ParseIntPipe({ optional: true }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], CatalogsController.prototype, "getClubIdeals", null);
exports.CatalogsController = CatalogsController = __decorate([
    (0, swagger_1.ApiTags)('catalogs'),
    (0, common_1.Controller)('catalogs'),
    __metadata("design:paramtypes", [catalogs_service_1.CatalogsService])
], CatalogsController);
//# sourceMappingURL=catalogs.controller.js.map