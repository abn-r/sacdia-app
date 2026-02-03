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
exports.UpdateUserDto = void 0;
const openapi = require("@nestjs/swagger");
const class_validator_1 = require("class-validator");
const swagger_1 = require("@nestjs/swagger");
const client_1 = require("@prisma/client");
class UpdateUserDto {
    gender;
    birthday;
    baptism;
    baptism_date;
    blood;
    static _OPENAPI_METADATA_FACTORY() {
        return { gender: { required: false, type: () => Object, enum: ['M', 'F'] }, birthday: { required: false, type: () => String }, baptism: { required: false, type: () => Boolean }, baptism_date: { required: false, type: () => String }, blood: { required: false, type: () => Object } };
    }
}
exports.UpdateUserDto = UpdateUserDto;
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ example: 'M', enum: ['M', 'F'] }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(['M', 'F']),
    __metadata("design:type", String)
], UpdateUserDto.prototype, "gender", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ example: '2000-01-15', description: 'Fecha de nacimiento (YYYY-MM-DD)' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], UpdateUserDto.prototype, "birthday", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ example: true }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], UpdateUserDto.prototype, "baptism", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({
        example: '2015-06-20',
        description: 'Fecha de bautismo (requerido si baptism=true)',
    }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    (0, class_validator_1.ValidateIf)((o) => o.baptism === true),
    __metadata("design:type", String)
], UpdateUserDto.prototype, "baptism_date", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({
        example: 'A_POSITIVE',
        enum: client_1.blood_type,
        description: 'Tipo de sangre'
    }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsEnum)(client_1.blood_type),
    __metadata("design:type", String)
], UpdateUserDto.prototype, "blood", void 0);
//# sourceMappingURL=update-user.dto.js.map