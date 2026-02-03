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
exports.FinanceFiltersDto = exports.UpdateFinanceDto = exports.CreateFinanceDto = void 0;
const openapi = require("@nestjs/swagger");
const class_validator_1 = require("class-validator");
const swagger_1 = require("@nestjs/swagger");
const class_transformer_1 = require("class-transformer");
class CreateFinanceDto {
    year;
    month;
    amount;
    description;
    club_type_id;
    finance_category_id;
    finance_date;
    club_adv_id;
    club_pathf_id;
    club_mg_id;
    static _OPENAPI_METADATA_FACTORY() {
        return { year: { required: true, type: () => Number }, month: { required: true, type: () => Number, minimum: 1 }, amount: { required: true, type: () => Number }, description: { required: false, type: () => String }, club_type_id: { required: true, type: () => Number }, finance_category_id: { required: true, type: () => Number }, finance_date: { required: true, type: () => String }, club_adv_id: { required: false, type: () => Number }, club_pathf_id: { required: false, type: () => Number }, club_mg_id: { required: false, type: () => Number } };
    }
}
exports.CreateFinanceDto = CreateFinanceDto;
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Año del movimiento' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateFinanceDto.prototype, "year", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Mes del movimiento (1-12)' }),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    __metadata("design:type", Number)
], CreateFinanceDto.prototype, "month", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Monto del movimiento (en centavos)' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateFinanceDto.prototype, "amount", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Descripción del movimiento' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateFinanceDto.prototype, "description", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Tipo de club (1=Aventureros, 2=Conquistadores, 3=GM)' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateFinanceDto.prototype, "club_type_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'ID de la categoría financiera' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateFinanceDto.prototype, "finance_category_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Fecha del movimiento' }),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], CreateFinanceDto.prototype, "finance_date", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'ID de la instancia de Aventureros' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateFinanceDto.prototype, "club_adv_id", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'ID de la instancia de Conquistadores' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateFinanceDto.prototype, "club_pathf_id", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'ID de la instancia de Guías Mayores' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateFinanceDto.prototype, "club_mg_id", void 0);
class UpdateFinanceDto {
    amount;
    description;
    finance_category_id;
    finance_date;
    static _OPENAPI_METADATA_FACTORY() {
        return { amount: { required: false, type: () => Number }, description: { required: false, type: () => String }, finance_category_id: { required: false, type: () => Number }, finance_date: { required: false, type: () => String } };
    }
}
exports.UpdateFinanceDto = UpdateFinanceDto;
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], UpdateFinanceDto.prototype, "amount", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateFinanceDto.prototype, "description", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], UpdateFinanceDto.prototype, "finance_category_id", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], UpdateFinanceDto.prototype, "finance_date", void 0);
class FinanceFiltersDto {
    year;
    month;
    clubTypeId;
    categoryId;
    static _OPENAPI_METADATA_FACTORY() {
        return { year: { required: false, type: () => Number }, month: { required: false, type: () => Number }, clubTypeId: { required: false, type: () => Number }, categoryId: { required: false, type: () => Number } };
    }
}
exports.FinanceFiltersDto = FinanceFiltersDto;
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Filtrar por año' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], FinanceFiltersDto.prototype, "year", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Filtrar por mes (1-12)' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], FinanceFiltersDto.prototype, "month", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Filtrar por tipo de club' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], FinanceFiltersDto.prototype, "clubTypeId", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Filtrar por categoría' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], FinanceFiltersDto.prototype, "categoryId", void 0);
//# sourceMappingURL=finances.dto.js.map