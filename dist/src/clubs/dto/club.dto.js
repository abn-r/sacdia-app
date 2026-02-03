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
exports.UpdateClubDto = exports.CreateClubDto = void 0;
const openapi = require("@nestjs/swagger");
const class_validator_1 = require("class-validator");
const swagger_1 = require("@nestjs/swagger");
class CreateClubDto {
    name;
    description;
    local_field_id;
    districlub_type_id;
    church_id;
    address;
    coordinates;
    static _OPENAPI_METADATA_FACTORY() {
        return { name: { required: true, type: () => String, maxLength: 50 }, description: { required: false, type: () => String }, local_field_id: { required: true, type: () => Number }, districlub_type_id: { required: true, type: () => Number }, church_id: { required: true, type: () => Number }, address: { required: false, type: () => String }, coordinates: { required: false, type: () => ({ lat: { required: true, type: () => Number }, lng: { required: true, type: () => Number } }) } };
    }
}
exports.CreateClubDto = CreateClubDto;
__decorate([
    (0, swagger_1.ApiProperty)({ example: 'Club Central', description: 'Nombre del club' }),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(50),
    __metadata("design:type", String)
], CreateClubDto.prototype, "name", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Descripción del club' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateClubDto.prototype, "description", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ example: 1, description: 'ID del campo local' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateClubDto.prototype, "local_field_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ example: 1, description: 'ID del distrito' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateClubDto.prototype, "districlub_type_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ example: 1, description: 'ID de la iglesia' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateClubDto.prototype, "church_id", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Dirección del club' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateClubDto.prototype, "address", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({
        example: { lat: 19.4326, lng: -99.1332 },
        description: 'Coordenadas del club',
    }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsObject)(),
    __metadata("design:type", Object)
], CreateClubDto.prototype, "coordinates", void 0);
class UpdateClubDto {
    name;
    description;
    address;
    coordinates;
    active;
    static _OPENAPI_METADATA_FACTORY() {
        return { name: { required: false, type: () => String, maxLength: 50 }, description: { required: false, type: () => String }, address: { required: false, type: () => String }, coordinates: { required: false, type: () => ({ lat: { required: true, type: () => Number }, lng: { required: true, type: () => Number } }) }, active: { required: false, type: () => Boolean } };
    }
}
exports.UpdateClubDto = UpdateClubDto;
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ example: 'Club Actualizado' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(50),
    __metadata("design:type", String)
], UpdateClubDto.prototype, "name", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateClubDto.prototype, "description", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateClubDto.prototype, "address", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsObject)(),
    __metadata("design:type", Object)
], UpdateClubDto.prototype, "coordinates", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], UpdateClubDto.prototype, "active", void 0);
//# sourceMappingURL=club.dto.js.map