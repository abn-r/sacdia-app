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
exports.ActivityFiltersDto = exports.RecordAttendanceDto = exports.UpdateActivityDto = exports.CreateActivityDto = void 0;
const openapi = require("@nestjs/swagger");
const class_validator_1 = require("class-validator");
const swagger_1 = require("@nestjs/swagger");
const class_transformer_1 = require("class-transformer");
class CreateActivityDto {
    name;
    description;
    club_type_id;
    lat;
    long;
    activity_time;
    activity_place;
    image;
    platform;
    activity_type;
    link_meet;
    additional_data;
    classes;
    club_adv_id;
    club_pathf_id;
    club_mg_id;
    static _OPENAPI_METADATA_FACTORY() {
        return { name: { required: true, type: () => String }, description: { required: false, type: () => String }, club_type_id: { required: true, type: () => Number }, lat: { required: true, type: () => Number, minimum: -90, maximum: 90 }, long: { required: true, type: () => Number, minimum: -180, maximum: 180 }, activity_time: { required: false, type: () => String }, activity_place: { required: true, type: () => String }, image: { required: true, type: () => String }, platform: { required: false, type: () => Number }, activity_type: { required: false, type: () => Number }, link_meet: { required: false, type: () => String }, additional_data: { required: false, type: () => String }, classes: { required: false, type: () => [Number] }, club_adv_id: { required: true, type: () => Number }, club_pathf_id: { required: true, type: () => Number }, club_mg_id: { required: true, type: () => Number } };
    }
}
exports.CreateActivityDto = CreateActivityDto;
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Nombre de la actividad' }),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateActivityDto.prototype, "name", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Descripción de la actividad' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateActivityDto.prototype, "description", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Tipo de club (1=Aventureros, 2=Conquistadores, 3=GM)' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateActivityDto.prototype, "club_type_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Latitud del lugar' }),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(-90),
    (0, class_validator_1.Max)(90),
    __metadata("design:type", Number)
], CreateActivityDto.prototype, "lat", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Longitud del lugar' }),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(-180),
    (0, class_validator_1.Max)(180),
    __metadata("design:type", Number)
], CreateActivityDto.prototype, "long", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Hora de la actividad (HH:mm)', default: '09:00' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateActivityDto.prototype, "activity_time", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Lugar de la actividad' }),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateActivityDto.prototype, "activity_place", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'URL de la imagen de la actividad' }),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateActivityDto.prototype, "image", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Plataforma (0=Presencial, 1=Virtual, 2=Híbrido)', default: 0 }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateActivityDto.prototype, "platform", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Tipo de actividad (0=Regular, 1=Especial, 2=Camporee)', default: 0 }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateActivityDto.prototype, "activity_type", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Link de reunión virtual' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateActivityDto.prototype, "link_meet", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Datos adicionales en JSON' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CreateActivityDto.prototype, "additional_data", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Clases invitadas (IDs)' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    __metadata("design:type", Array)
], CreateActivityDto.prototype, "classes", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'ID de la instancia de Aventureros' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateActivityDto.prototype, "club_adv_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'ID de la instancia de Conquistadores' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateActivityDto.prototype, "club_pathf_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'ID de la instancia de Guías Mayores' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateActivityDto.prototype, "club_mg_id", void 0);
class UpdateActivityDto {
    name;
    description;
    lat;
    long;
    activity_time;
    activity_place;
    image;
    platform;
    activity_type;
    link_meet;
    active;
    classes;
    static _OPENAPI_METADATA_FACTORY() {
        return { name: { required: false, type: () => String }, description: { required: false, type: () => String }, lat: { required: false, type: () => Number }, long: { required: false, type: () => Number }, activity_time: { required: false, type: () => String }, activity_place: { required: false, type: () => String }, image: { required: false, type: () => String }, platform: { required: false, type: () => Number }, activity_type: { required: false, type: () => Number }, link_meet: { required: false, type: () => String }, active: { required: false, type: () => Boolean }, classes: { required: false, type: () => [Number] } };
    }
}
exports.UpdateActivityDto = UpdateActivityDto;
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateActivityDto.prototype, "name", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateActivityDto.prototype, "description", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    __metadata("design:type", Number)
], UpdateActivityDto.prototype, "lat", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    __metadata("design:type", Number)
], UpdateActivityDto.prototype, "long", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateActivityDto.prototype, "activity_time", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateActivityDto.prototype, "activity_place", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateActivityDto.prototype, "image", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], UpdateActivityDto.prototype, "platform", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], UpdateActivityDto.prototype, "activity_type", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateActivityDto.prototype, "link_meet", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], UpdateActivityDto.prototype, "active", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    __metadata("design:type", Array)
], UpdateActivityDto.prototype, "classes", void 0);
class RecordAttendanceDto {
    user_ids;
    static _OPENAPI_METADATA_FACTORY() {
        return { user_ids: { required: true, type: () => [String] } };
    }
}
exports.RecordAttendanceDto = RecordAttendanceDto;
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Lista de IDs de usuarios que asistieron' }),
    (0, class_validator_1.IsArray)(),
    __metadata("design:type", Array)
], RecordAttendanceDto.prototype, "user_ids", void 0);
class ActivityFiltersDto {
    clubTypeId;
    active;
    activityType;
    static _OPENAPI_METADATA_FACTORY() {
        return { clubTypeId: { required: false, type: () => Number }, active: { required: false, type: () => Boolean }, activityType: { required: false, type: () => Number } };
    }
}
exports.ActivityFiltersDto = ActivityFiltersDto;
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Filtrar por tipo de club' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], ActivityFiltersDto.prototype, "clubTypeId", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Solo actividades activas' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], ActivityFiltersDto.prototype, "active", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Tipo de actividad' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], ActivityFiltersDto.prototype, "activityType", void 0);
//# sourceMappingURL=activities.dto.js.map