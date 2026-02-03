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
exports.UnenrollMfaDto = exports.VerifyMfaDto = void 0;
const openapi = require("@nestjs/swagger");
const class_validator_1 = require("class-validator");
const swagger_1 = require("@nestjs/swagger");
class VerifyMfaDto {
    factorId;
    code;
    static _OPENAPI_METADATA_FACTORY() {
        return { factorId: { required: true, type: () => String }, code: { required: true, type: () => String, minLength: 6, maxLength: 6 } };
    }
}
exports.VerifyMfaDto = VerifyMfaDto;
__decorate([
    (0, swagger_1.ApiProperty)({
        example: 'abc123-factor-id',
        description: 'ID del factor MFA a verificar',
    }),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], VerifyMfaDto.prototype, "factorId", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({
        example: '123456',
        description: 'Código TOTP de 6 dígitos de tu app de autenticación',
    }),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Length)(6, 6, { message: 'El código debe tener 6 dígitos' }),
    __metadata("design:type", String)
], VerifyMfaDto.prototype, "code", void 0);
class UnenrollMfaDto {
    factorId;
    static _OPENAPI_METADATA_FACTORY() {
        return { factorId: { required: true, type: () => String } };
    }
}
exports.UnenrollMfaDto = UnenrollMfaDto;
__decorate([
    (0, swagger_1.ApiProperty)({
        example: 'abc123-factor-id',
        description: 'ID del factor MFA a eliminar',
    }),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UnenrollMfaDto.prototype, "factorId", void 0);
//# sourceMappingURL=mfa.dto.js.map