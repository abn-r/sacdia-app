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
exports.UpdateInstanceDto = exports.CreateInstanceDto = exports.ClubInstanceType = void 0;
const openapi = require("@nestjs/swagger");
const class_validator_1 = require("class-validator");
const swagger_1 = require("@nestjs/swagger");
var ClubInstanceType;
(function (ClubInstanceType) {
    ClubInstanceType["ADVENTURERS"] = "adventurers";
    ClubInstanceType["PATHFINDERS"] = "pathfinders";
    ClubInstanceType["MASTER_GUILDS"] = "master_guilds";
})(ClubInstanceType || (exports.ClubInstanceType = ClubInstanceType = {}));
class CreateInstanceDto {
    type;
    souls_target;
    fee;
    meeting_day;
    meeting_time;
    static _OPENAPI_METADATA_FACTORY() {
        return { type: { required: true, enum: require("./instance.dto").ClubInstanceType }, souls_target: { required: false, type: () => Number }, fee: { required: false, type: () => Number }, meeting_day: { required: false, type: () => [Object] }, meeting_time: { required: false, type: () => [Object] } };
    }
}
exports.CreateInstanceDto = CreateInstanceDto;
__decorate([
    (0, swagger_1.ApiProperty)({
        enum: ClubInstanceType,
        example: 'pathfinders',
        description: 'Tipo de instancia a crear',
    }),
    __metadata("design:type", String)
], CreateInstanceDto.prototype, "type", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ example: 1, description: 'Meta de almas' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateInstanceDto.prototype, "souls_target", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ example: 100, description: 'Cuota mensual' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CreateInstanceDto.prototype, "fee", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({
        example: [{ day: 'Saturday' }],
        description: 'Días de reunión',
    }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    __metadata("design:type", Array)
], CreateInstanceDto.prototype, "meeting_day", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({
        example: [{ time: '09:00' }],
        description: 'Horarios de reunión',
    }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    __metadata("design:type", Array)
], CreateInstanceDto.prototype, "meeting_time", void 0);
class UpdateInstanceDto {
    souls_target;
    fee;
    meeting_day;
    meeting_time;
    active;
    static _OPENAPI_METADATA_FACTORY() {
        return { souls_target: { required: false, type: () => Number }, fee: { required: false, type: () => Number }, meeting_day: { required: false, type: () => [Object] }, meeting_time: { required: false, type: () => [Object] }, active: { required: false, type: () => Boolean } };
    }
}
exports.UpdateInstanceDto = UpdateInstanceDto;
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], UpdateInstanceDto.prototype, "souls_target", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], UpdateInstanceDto.prototype, "fee", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    __metadata("design:type", Array)
], UpdateInstanceDto.prototype, "meeting_day", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    __metadata("design:type", Array)
], UpdateInstanceDto.prototype, "meeting_time", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)(),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], UpdateInstanceDto.prototype, "active", void 0);
//# sourceMappingURL=instance.dto.js.map