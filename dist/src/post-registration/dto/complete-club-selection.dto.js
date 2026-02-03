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
exports.CompleteClubSelectionDto = void 0;
const openapi = require("@nestjs/swagger");
const class_validator_1 = require("class-validator");
const swagger_1 = require("@nestjs/swagger");
class CompleteClubSelectionDto {
    country_id;
    union_id;
    local_field_id;
    club_type;
    club_instance_id;
    class_id;
    static _OPENAPI_METADATA_FACTORY() {
        return { country_id: { required: true, type: () => Number }, union_id: { required: true, type: () => Number }, local_field_id: { required: true, type: () => Number }, club_type: { required: true, type: () => Object, enum: ['adventurers', 'pathfinders', 'master_guild'] }, club_instance_id: { required: true, type: () => Number }, class_id: { required: true, type: () => Number } };
    }
}
exports.CompleteClubSelectionDto = CompleteClubSelectionDto;
__decorate([
    (0, swagger_1.ApiProperty)({ example: 1, description: 'ID del país' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CompleteClubSelectionDto.prototype, "country_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ example: 1, description: 'ID de la unión' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CompleteClubSelectionDto.prototype, "union_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ example: 1, description: 'ID del campo local' }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CompleteClubSelectionDto.prototype, "local_field_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({
        example: 'adventurers',
        enum: ['adventurers', 'pathfinders', 'master_guild'],
        description: 'Tipo de club',
    }),
    (0, class_validator_1.IsIn)(['adventurers', 'pathfinders', 'master_guild']),
    __metadata("design:type", String)
], CompleteClubSelectionDto.prototype, "club_type", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({
        example: 1,
        description: 'ID de la instancia del club (club_adv_id, club_pathf_id, o club_mg_id)',
    }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CompleteClubSelectionDto.prototype, "club_instance_id", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({
        example: 1,
        description: 'ID de la clase a inscribirse',
    }),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Number)
], CompleteClubSelectionDto.prototype, "class_id", void 0);
//# sourceMappingURL=complete-club-selection.dto.js.map