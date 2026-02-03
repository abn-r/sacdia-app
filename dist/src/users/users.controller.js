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
exports.UsersController = void 0;
const openapi = require("@nestjs/swagger");
const common_1 = require("@nestjs/common");
const platform_express_1 = require("@nestjs/platform-express");
const swagger_1 = require("@nestjs/swagger");
const users_service_1 = require("./users.service");
const update_user_dto_1 = require("./dto/update-user.dto");
const jwt_auth_guard_1 = require("../common/guards/jwt-auth.guard");
let UsersController = class UsersController {
    usersService;
    constructor(usersService) {
        this.usersService = usersService;
    }
    async findOne(userId) {
        return this.usersService.findOne(userId);
    }
    async update(userId, updateUserDto) {
        return this.usersService.update(userId, updateUserDto);
    }
    async uploadProfilePicture(userId, file) {
        return this.usersService.uploadProfilePicture(userId, file);
    }
    async deleteProfilePicture(userId) {
        return this.usersService.deleteProfilePicture(userId);
    }
    async getAge(userId) {
        const age = await this.usersService.calculateAge(userId);
        return {
            status: 'success',
            data: { age },
        };
    }
    async requiresLegalRepresentative(userId) {
        const age = await this.usersService.calculateAge(userId);
        const required = await this.usersService.requiresLegalRepresentative(userId);
        return {
            status: 'success',
            data: {
                required,
                userAge: age,
                reason: required
                    ? 'Usuario es menor de 18 años'
                    : 'Usuario es mayor de edad',
            },
        };
    }
};
exports.UsersController = UsersController;
__decorate([
    (0, common_1.Get)(':userId'),
    (0, swagger_1.ApiOperation)({ summary: 'Obtener información de un usuario' }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Usuario encontrado' }),
    (0, swagger_1.ApiResponse)({ status: 404, description: 'Usuario no encontrado' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "findOne", null);
__decorate([
    (0, common_1.Patch)(':userId'),
    (0, swagger_1.ApiOperation)({ summary: 'Actualizar información personal del usuario' }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Usuario actualizado' }),
    (0, swagger_1.ApiResponse)({ status: 404, description: 'Usuario no encontrado' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_user_dto_1.UpdateUserDto]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "update", null);
__decorate([
    (0, common_1.Post)(':userId/profile-picture'),
    (0, common_1.UseInterceptors)((0, platform_express_1.FileInterceptor)('file')),
    (0, swagger_1.ApiConsumes)('multipart/form-data'),
    (0, swagger_1.ApiOperation)({ summary: 'Subir foto de perfil' }),
    (0, swagger_1.ApiBody)({
        schema: {
            type: 'object',
            properties: {
                file: {
                    type: 'string',
                    format: 'binary',
                },
            },
        },
    }),
    (0, swagger_1.ApiResponse)({ status: 201, description: 'Foto subida exitosamente' }),
    (0, swagger_1.ApiResponse)({ status: 400, description: 'Formato o tamaño inválido' }),
    openapi.ApiResponse({ status: 201 }),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.UploadedFile)(new common_1.ParseFilePipe({
        validators: [
            new common_1.MaxFileSizeValidator({ maxSize: 5 * 1024 * 1024 }),
            new common_1.FileTypeValidator({ fileType: /(jpg|jpeg|png|webp)$/ }),
        ],
    }))),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "uploadProfilePicture", null);
__decorate([
    (0, common_1.Delete)(':userId/profile-picture'),
    (0, swagger_1.ApiOperation)({ summary: 'Eliminar foto de perfil' }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Foto eliminada' }),
    (0, swagger_1.ApiResponse)({ status: 404, description: 'Usuario sin foto de perfil' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "deleteProfilePicture", null);
__decorate([
    (0, common_1.Get)(':userId/age'),
    (0, swagger_1.ApiOperation)({ summary: 'Calcular edad del usuario' }),
    (0, swagger_1.ApiResponse)({ status: 200, description: 'Edad calculada' }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "getAge", null);
__decorate([
    (0, common_1.Get)(':userId/requires-legal-representative'),
    (0, swagger_1.ApiOperation)({
        summary: 'Verificar si el usuario requiere representante legal',
    }),
    (0, swagger_1.ApiResponse)({
        status: 200,
        description: 'Si requiere (edad < 18) o no',
    }),
    openapi.ApiResponse({ status: 200 }),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "requiresLegalRepresentative", null);
exports.UsersController = UsersController = __decorate([
    (0, swagger_1.ApiTags)('users'),
    (0, common_1.Controller)('users'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, swagger_1.ApiBearerAuth)(),
    __metadata("design:paramtypes", [users_service_1.UsersService])
], UsersController);
//# sourceMappingURL=users.controller.js.map