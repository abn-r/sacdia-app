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
exports.UpdateProgressDto = exports.EnrollClassDto = void 0;
const openapi = require("@nestjs/swagger");
const class_validator_1 = require("class-validator");
const swagger_1 = require("@nestjs/swagger");
class EnrollClassDto {
    class_id;
    ecclesiastical_year_id;
    static _OPENAPI_METADATA_FACTORY() {
        return { class_id: { required: true, type: () => Number }, ecclesiastical_year_id: { required: true, type: () => Number } };
    }
}
exports.EnrollClassDto = EnrollClassDto;
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'ID de la clase' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], EnrollClassDto.prototype, "class_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'ID del año eclesiástico' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], EnrollClassDto.prototype, "ecclesiastical_year_id", void 0);
class UpdateProgressDto {
    module_id;
    section_id;
    score;
    evidences;
    static _OPENAPI_METADATA_FACTORY() {
        return { module_id: { required: true, type: () => Number }, section_id: { required: true, type: () => Number }, score: { required: true, type: () => Number, minimum: 0, maximum: 100 }, evidences: { required: false, type: () => Object } };
    }
}
exports.UpdateProgressDto = UpdateProgressDto;
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'ID del módulo' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], UpdateProgressDto.prototype, "module_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'ID de la sección' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], UpdateProgressDto.prototype, "section_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({
        description: 'Puntaje obtenido (0-100)',
        minimum: 0,
        maximum: 100,
    }),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    (0, class_validator_1.Max)(100),
    __metadata("design:type", Number)
], UpdateProgressDto.prototype, "score", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({
        description: 'Evidencias en formato JSON (URLs, notas, etc.)',
    }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsObject)(),
    __metadata("design:type", Object)
], UpdateProgressDto.prototype, "evidences", void 0);
//# sourceMappingURL=classes.dto.js.map