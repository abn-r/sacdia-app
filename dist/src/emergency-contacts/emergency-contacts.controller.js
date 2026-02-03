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
exports.EmergencyContactsController = void 0;
const openapi = require("@nestjs/swagger");
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const emergency_contacts_service_1 = require("./emergency-contacts.service");
const create_emergency_contact_dto_1 = require("./dto/create-emergency-contact.dto");
const update_emergency_contact_dto_1 = require("./dto/update-emergency-contact.dto");
const jwt_auth_guard_1 = require("../common/guards/jwt-auth.guard");
let EmergencyContactsController = class EmergencyContactsController {
    emergencyContactsService;
    constructor(emergencyContactsService) {
        this.emergencyContactsService = emergencyContactsService;
    }
    async create(userId, createDto) {
        return this.emergencyContactsService.create(userId, createDto);
    }
    async findAll(userId) {
        return this.emergencyContactsService.findAll(userId);
    }
    async findOne(userId, contactId) {
        return this.emergencyContactsService.findOne(contactId, userId);
    }
    async update(userId, contactId, updateDto) {
        return this.emergencyContactsService.update(contactId, userId, updateDto);
    }
    async remove(userId, contactId) {
        return this.emergencyContactsService.remove(contactId, userId);
    }
};
exports.EmergencyContactsController = EmergencyContactsController;
__decorate([
    (0, common_1.Post)(),
    (0, swagger_1.ApiOperation)({ summary: 'Crear contacto de emergencia (máximo 5)' }),
    (0, swagger_1.ApiResponse)({ status: 201, description: 'Contacto creado' }),
    (0, swagger_1.ApiResponse)({ status: 400, description: 'Máximo de contactos alcanzado' }),
    openapi.ApiResponse({ status: 201 }),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, create_emergency_contact_dto_1.CreateEmergencyContactDto]),
    __metadata("design:returntype", Promise)
], EmergencyContactsController.prototype, "create", null);
__decorate([
    (0, common_1.Get)(),
    (0, swagger_1.ApiOperation)({ summary: 'Listar contactos de emergencia del usuario' }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Lista de contactos' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], EmergencyContactsController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)(':contactId'),
    (0, swagger_1.ApiOperation)({ summary: 'Obtener un contacto específico' }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Contacto encontrado' }),
    (0, swagger_1.ApiResponse)({ status: 404, description: 'Contacto no encontrado' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Param)('contactId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Number]),
    __metadata("design:returntype", Promise)
], EmergencyContactsController.prototype, "findOne", null);
__decorate([
    (0, common_1.Patch)(':contactId'),
    (0, swagger_1.ApiOperation)({ summary: 'Actualizar contacto de emergencia' }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Contacto actualizado' }),
    (0, swagger_1.ApiResponse)({ status: 404, description: 'Contacto no encontrado' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Param)('contactId', common_1.ParseIntPipe)),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Number, update_emergency_contact_dto_1.UpdateEmergencyContactDto]),
    __metadata("design:returntype", Promise)
], EmergencyContactsController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':contactId'),
    (0, swagger_1.ApiOperation)({ summary: 'Eliminar contacto de emergencia (soft delete)' }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Contacto eliminado' }),
    (0, swagger_1.ApiResponse)({ status: 404, description: 'Contacto no encontrado' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Param)('contactId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Number]),
    __metadata("design:returntype", Promise)
], EmergencyContactsController.prototype, "remove", null);
exports.EmergencyContactsController = EmergencyContactsController = __decorate([
    (0, swagger_1.ApiTags)('emergency-contacts'),
    (0, common_1.Controller)('users/:userId/emergency-contacts'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, swagger_1.ApiBearerAuth)(),
    __metadata("design:paramtypes", [emergency_contacts_service_1.EmergencyContactsService])
], EmergencyContactsController);
//# sourceMappingURL=emergency-contacts.controller.js.map