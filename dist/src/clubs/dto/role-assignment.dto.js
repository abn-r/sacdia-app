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
Object.defineProperty(exports, "__esModule", { value: true });
exports.UpdateRoleAssignmentDto = exports.AssignRoleDto = void 0;
const openapi = require("@nestjs/swagger");
const class_validator_1 = require("class-validator");
const swagger_1 = require("@nestjs/swagger");
const class_transformer_1 = require("class-transformer");
const instance_dto_1 = require("./instance.dto");
class AssignRoleDto {
    user_id;
    role_id;
    instance_type;
    instance_id;
    ecclesiastical_year_id;
    start_date;
    end_date;
    static _OPENAPI_METADATA_FACTORY() {
        return { user_id: { required: true, type: () => String, format: "uuid" }, role_id: { required: true, type: () => String, format: "uuid" }, instance_type: { required: true, enum: require("./instance.dto").ClubInstanceType }, instance_id: { required: true, type: () => Number }, ecclesiastical_year_id: { required: true, type: () => Number }, start_date: { required: true, type: () => Date }, end_date: { required: false, type: () => Date } };
    }
}
exports.AssignRoleDto = AssignRoleDto;
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'ID del usuario' }),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], AssignRoleDto.prototype, "user_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'ID del rol a asignar' }),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], AssignRoleDto.prototype, "role_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({
        enum: instance_dto_1.ClubInstanceType,
        description: 'Tipo de instancia de club',
    }),
    __metadata("design:type", String)
], AssignRoleDto.prototype, "instance_type", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'ID de la instancia de club' }),
    __metadata("design:type", Number)
], AssignRoleDto.prototype, "instance_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'ID del año eclesiástico' }),
    __metadata("design:type", Number)
], AssignRoleDto.prototype, "ecclesiastical_year_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Fecha de inicio del rol' }),
    (0, class_validator_1.IsDate)(),
    (0, class_transformer_1.Type)(() => Date),
    __metadata("design:type", Date)
], AssignRoleDto.prototype, "start_date", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Fecha de fin del rol' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDate)(),
    (0, class_transformer_1.Type)(() => Date),
    __metadata("design:type", Date)
], AssignRoleDto.prototype, "end_date", void 0);
class UpdateRoleAssignmentDto {
    end_date;
    status;
    static _OPENAPI_METADATA_FACTORY() {
        return { end_date: { required: false, type: () => Date }, status: { required: false, type: () => String } };
    }
}
exports.UpdateRoleAssignmentDto = UpdateRoleAssignmentDto;
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Fecha de fin del rol' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDate)(),
    (0, class_transformer_1.Type)(() => Date),
    __metadata("design:type", Date)
], UpdateRoleAssignmentDto.prototype, "end_date", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Estado del rol' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateRoleAssignmentDto.prototype, "status", void 0);
//# sourceMappingURL=role-assignment.dto.js.map