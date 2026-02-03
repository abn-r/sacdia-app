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
var LegalRepresentativesService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.LegalRepresentativesService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
const users_service_1 = require("../users/users.service");
let LegalRepresentativesService = LegalRepresentativesService_1 = class LegalRepresentativesService {
    prisma;
    usersService;
    logger = new common_1.Logger(LegalRepresentativesService_1.name);
    constructor(prisma, usersService) {
        this.prisma = prisma;
        this.usersService = usersService;
    }
    async create(userId, createDto) {
        const requiresRep = await this.usersService.requiresLegalRepresentative(userId);
        if (!requiresRep) {
            throw new common_1.BadRequestException('Usuario mayor de 18 años no requiere representante legal');
        }
        const existing = await this.prisma.legal_representatives.findUnique({
            where: { user_id: userId },
        });
        if (existing) {
            throw new common_1.ConflictException('El usuario ya tiene un representante legal');
        }
        if (!createDto.representative_user_id &&
            (!createDto.name || !createDto.paternal_last_name || !createDto.phone)) {
            throw new common_1.BadRequestException('Debe proporcionar representative_user_id O los datos completos (name, paternal_last_name, phone)');
        }
        if (createDto.representative_user_id) {
            const repUser = await this.prisma.users.findUnique({
                where: { user_id: createDto.representative_user_id },
            });
            if (!repUser) {
                throw new common_1.NotFoundException('Usuario representante no encontrado');
            }
        }
        const relType = await this.prisma.relationship_types.findUnique({
            where: { relationship_type_id: createDto.relationship_type_id },
        });
        if (!relType) {
            throw new common_1.NotFoundException('Tipo de relación no encontrado');
        }
        const representative = await this.prisma.legal_representatives.create({
            data: {
                user_id: userId,
                representative_user_id: createDto.representative_user_id,
                name: createDto.name,
                paternal_last_name: createDto.paternal_last_name,
                maternal_last_name: createDto.maternal_last_name,
                phone: createDto.phone,
                relationship_type_id: createDto.relationship_type_id,
            },
            include: {
                relationship_types: {
                    select: {
                        name: true,
                    },
                },
            },
        });
        this.logger.log(`Legal representative created for user ${userId}`);
        return {
            status: 'success',
            data: representative,
            message: 'Representante legal registrado exitosamente',
        };
    }
    async findOne(userId) {
        const representative = await this.prisma.legal_representatives.findUnique({
            where: { user_id: userId },
            include: {
                representative_user: {
                    select: {
                        user_id: true,
                        email: true,
                        name: true,
                        paternal_last_name: true,
                        maternal_last_name: true,
                    },
                },
                relationship_types: {
                    select: {
                        relationship_type_id: true,
                        name: true,
                    },
                },
            },
        });
        if (!representative) {
            throw new common_1.NotFoundException('Representante legal no encontrado');
        }
        return { status: 'success', data: representative };
    }
    async update(userId, updateDto) {
        const existing = await this.prisma.legal_representatives.findUnique({
            where: { user_id: userId },
        });
        if (!existing) {
            throw new common_1.NotFoundException('Representante legal no encontrado');
        }
        if (updateDto.representative_user_id) {
            const repUser = await this.prisma.users.findUnique({
                where: { user_id: updateDto.representative_user_id },
            });
            if (!repUser) {
                throw new common_1.NotFoundException('Usuario representante no encontrado');
            }
        }
        if (updateDto.relationship_type_id) {
            const relType = await this.prisma.relationship_types.findUnique({
                where: { relationship_type_id: updateDto.relationship_type_id },
            });
            if (!relType) {
                throw new common_1.NotFoundException('Tipo de relación no encontrado');
            }
        }
        const updated = await this.prisma.legal_representatives.update({
            where: { user_id: userId },
            data: updateDto,
            include: {
                relationship_types: {
                    select: {
                        name: true,
                    },
                },
            },
        });
        this.logger.log(`Legal representative updated for user ${userId}`);
        return {
            status: 'success',
            data: updated,
            message: 'Representante legal actualizado exitosamente',
        };
    }
    async remove(userId) {
        const existing = await this.prisma.legal_representatives.findUnique({
            where: { user_id: userId },
        });
        if (!existing) {
            throw new common_1.NotFoundException('Representante legal no encontrado');
        }
        await this.prisma.legal_representatives.delete({
            where: { user_id: userId },
        });
        this.logger.log(`Legal representative deleted for user ${userId}`);
        return {
            status: 'success',
            message: 'Representante legal eliminado exitosamente',
        };
    }
};
exports.LegalRepresentativesService = LegalRepresentativesService;
exports.LegalRepresentativesService = LegalRepresentativesService = LegalRepresentativesService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        users_service_1.UsersService])
], LegalRepresentativesService);
//# sourceMappingURL=legal-representatives.service.js.map