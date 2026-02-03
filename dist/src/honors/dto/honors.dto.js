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
exports.HonorFiltersDto = exports.UpdateUserHonorDto = exports.StartHonorDto = void 0;
const openapi = require("@nestjs/swagger");
const class_validator_1 = require("class-validator");
const swagger_1 = require("@nestjs/swagger");
class StartHonorDto {
    date;
    static _OPENAPI_METADATA_FACTORY() {
        return { date: { required: false, type: () => String } };
    }
}
exports.StartHonorDto = StartHonorDto;
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Fecha de inicio del honor' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], StartHonorDto.prototype, "date", void 0);
class UpdateUserHonorDto {
    validate;
    certificate;
    images;
    document;
    date;
    static _OPENAPI_METADATA_FACTORY() {
        return { validate: { required: false, type: () => Boolean }, certificate: { required: false, type: () => String }, images: { required: false, type: () => [String] }, document: { required: false, type: () => String }, date: { required: false, type: () => String } };
    }
}
exports.UpdateUserHonorDto = UpdateUserHonorDto;
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Honor validado por instructor' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], UpdateUserHonorDto.prototype, "validate", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'URL del certificado' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateUserHonorDto.prototype, "certificate", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'URLs de imágenes de evidencia' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    __metadata("design:type", Array)
], UpdateUserHonorDto.prototype, "images", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'URL del documento adicional' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateUserHonorDto.prototype, "document", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Fecha de completación' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], UpdateUserHonorDto.prototype, "date", void 0);
class HonorFiltersDto {
    categoryId;
    clubTypeId;
    skillLevel;
    static _OPENAPI_METADATA_FACTORY() {
        return { categoryId: { required: false, type: () => Number }, clubTypeId: { required: false, type: () => Number }, skillLevel: { required: false, type: () => Number } };
    }
}
exports.HonorFiltersDto = HonorFiltersDto;
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Filtrar por categoría de honor' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], HonorFiltersDto.prototype, "categoryId", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Filtrar por tipo de club' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], HonorFiltersDto.prototype, "clubTypeId", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Filtrar por nivel de habilidad (1-3)' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], HonorFiltersDto.prototype, "skillLevel", void 0);
//# sourceMappingURL=honors.dto.js.map