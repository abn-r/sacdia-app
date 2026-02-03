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
exports.LegalRepresentativesController = void 0;
const openapi = require("@nestjs/swagger");
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const legal_representatives_service_1 = require("./legal-representatives.service");
const create_legal_representative_dto_1 = require("./dto/create-legal-representative.dto");
const update_legal_representative_dto_1 = require("./dto/update-legal-representative.dto");
const jwt_auth_guard_1 = require("../common/guards/jwt-auth.guard");
let LegalRepresentativesController = class LegalRepresentativesController {
    legalRepresentativesService;
    constructor(legalRepresentativesService) {
        this.legalRepresentativesService = legalRepresentativesService;
    }
    async create(userId, createDto) {
        return this.legalRepresentativesService.create(userId, createDto);
    }
    async findOne(userId) {
        return this.legalRepresentativesService.findOne(userId);
    }
    async update(userId, updateDto) {
        return this.legalRepresentativesService.update(userId, updateDto);
    }
    async remove(userId) {
        return this.legalRepresentativesService.remove(userId);
    }
};
exports.LegalRepresentativesController = LegalRepresentativesController;
__decorate([
    (0, common_1.Post)(),
    (0, swagger_1.ApiOperation)({
        summary: 'Registrar representante legal (solo para menores de 18)',
    }),
    (0, swagger_1.ApiResponse)({ status: 201, description: 'Representante registrado' }),
    (0, swagger_1.ApiResponse)({
        status: 400,
        description: 'Usuario mayor de edad o ya tiene representante',
    }),
    openapi.ApiResponse({ status: 201 }),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, create_legal_representative_dto_1.CreateLegalRepresentativeDto]),
    __metadata("design:returntype", Promise)
], LegalRepresentativesController.prototype, "create", null);
__decorate([
    (0, common_1.Get)(),
    (0, swagger_1.ApiOperation)({ summary: 'Obtener representante legal del usuario' }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Representante encontrado' }),
    (0, swagger_1.ApiResponse)({ status: 404, description: 'Representante no encontrado' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], LegalRepresentativesController.prototype, "findOne", null);
__decorate([
    (0, common_1.Patch)(),
    (0, swagger_1.ApiOperation)({ summary: 'Actualizar representante legal' }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Representante actualizado' }),
    (0, swagger_1.ApiResponse)({ status: 404, description: 'Representante no encontrado' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_legal_representative_dto_1.UpdateLegalRepresentativeDto]),
    __metadata("design:returntype", Promise)
], LegalRepresentativesController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(),
    (0, swagger_1.ApiOperation)({ summary: 'Eliminar representante legal' }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Representante eliminado' }),
    (0, swagger_1.ApiResponse)({ status: 404, description: 'Representante no encontrado' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], LegalRepresentativesController.prototype, "remove", null);
exports.LegalRepresentativesController = LegalRepresentativesController = __decorate([
    (0, swagger_1.ApiTags)('legal-representatives'),
    (0, common_1.Controller)('users/:userId/legal-representative'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, swagger_1.ApiBearerAuth)(),
    __metadata("design:paramtypes", [legal_representatives_service_1.LegalRepresentativesService])
], LegalRepresentativesController);
//# sourceMappingURL=legal-representatives.controller.js.map