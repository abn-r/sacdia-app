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
exports.CreateLegalRepresentativeDto = void 0;
const openapi = require("@nestjs/swagger");
const class_validator_1 = require("class-validator");
const swagger_1 = require("@nestjs/swagger");
class CreateLegalRepresentativeDto {
    representative_user_id;
    name;
    paternal_last_name;
    maternal_last_name;
    phone;
    relationship_type_id;
    static _OPENAPI_METADATA_FACTORY() {
        return { representative_user_id: { required: false, type: () => String, format: "uuid" }, name: { required: false, type: () => String, maxLength: 100 }, paternal_last_name: { required: false, type: () => String, maxLength: 100 }, maternal_last_name: { required: false, type: () => String, maxLength: 100 }, phone: { required: false, type: () => String, maxLength: 20 }, relationship_type_id: { required: true, type: () => String, format: "uuid" } };
    }
}
exports.CreateLegalRepresentativeDto = CreateLegalRepresentativeDto;
__decorate([
    (0, swagger_1.ApiPropertyOptional)({
        description: 'ID del usuario registrado que es el representante legal',
    }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], CreateLegalRepresentativeDto.prototype, "representative_user_id", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({
        description: 'Nombre (requerido si no se proporciona representative_user_id)',
    }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(100),
    (0, class_validator_1.ValidateIf)((o) => !o.representative_user_id),
    __metadata("design:type", String)
], CreateLegalRepresentativeDto.prototype, "name", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({
        description: 'Apellido paterno (requerido si no se proporciona representative_user_id)',
    }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(100),
    (0, class_validator_1.ValidateIf)((o) => !o.representative_user_id),
    __metadata("design:type", String)
], CreateLegalRepresentativeDto.prototype, "paternal_last_name", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Apellido materno' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(100),
    __metadata("design:type", String)
], CreateLegalRepresentativeDto.prototype, "maternal_last_name", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({
        description: 'Teléfono (requerido si no se proporciona representative_user_id)',
    }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(20),
    (0, class_validator_1.ValidateIf)((o) => !o.representative_user_id),
    __metadata("design:type", String)
], CreateLegalRepresentativeDto.prototype, "phone", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'UUID del tipo de relación' }),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], CreateLegalRepresentativeDto.prototype, "relationship_type_id", void 0);
//# sourceMappingURL=create-legal-representative.dto.js.map