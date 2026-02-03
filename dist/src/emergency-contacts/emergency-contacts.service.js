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
var EmergencyContactsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.EmergencyContactsService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
let EmergencyContactsService = EmergencyContactsService_1 = class EmergencyContactsService {
    prisma;
    logger = new common_1.Logger(EmergencyContactsService_1.name);
    MAX_CONTACTS = 5;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async create(userId, createDto) {
        const activeCount = await this.prisma.emergency_contacts.count({
            where: {
                owner_id: userId,
                active: true,
            },
        });
        if (activeCount >= this.MAX_CONTACTS) {
            throw new common_1.BadRequestException(`Máximo ${this.MAX_CONTACTS} contactos de emergencia permitidos`);
        }
        const duplicate = await this.prisma.emergency_contacts.findFirst({
            where: {
                owner_id: userId,
                name: createDto.name,
                phone: createDto.phone,
                active: true,
            },
        });
        if (duplicate) {
            throw new common_1.ConflictException('Este contacto ya existe');
        }
        if (createDto.primary) {
            await this.prisma.emergency_contacts.updateMany({
                where: {
                    owner_id: userId,
                    active: true,
                },
                data: {
                    primary: false,
                },
            });
        }
        const contact = await this.prisma.emergency_contacts.create({
            data: {
                owner_id: userId,
                name: createDto.name,
                relationship_type: createDto.relationship_type,
                phone: createDto.phone,
                primary: createDto.primary ?? false,
                active: true,
            },
        });
        this.logger.log(`Emergency contact created for user ${userId}`);
        return {
            status: 'success',
            data: contact,
            message: 'Contacto de emergencia creado exitosamente',
        };
    }
    async findAll(userId) {
        const contacts = await this.prisma.emergency_contacts.findMany({
            where: {
                owner_id: userId,
                active: true,
            },
            orderBy: [{ primary: 'desc' }, { created_at: 'asc' }],
            select: {
                emergency_id: true,
                name: true,
                relationship_type: true,
                phone: true,
                primary: true,
                created_at: true,
                modified_at: true,
            },
        });
        return {
            status: 'success',
            data: contacts,
            meta: {
                total: contacts.length,
                remaining: this.MAX_CONTACTS - contacts.length,
            },
        };
    }
    async findOne(contactId, userId) {
        const contact = await this.prisma.emergency_contacts.findFirst({
            where: {
                emergency_id: contactId,
                owner_id: userId,
                active: true,
            },
        });
        if (!contact) {
            throw new common_1.NotFoundException('Contacto de emergencia no encontrado');
        }
        return { status: 'success', data: contact };
    }
    async update(contactId, userId, updateDto) {
        const existingContact = await this.prisma.emergency_contacts.findFirst({
            where: {
                emergency_id: contactId,
                owner_id: userId,
                active: true,
            },
        });
        if (!existingContact) {
            throw new common_1.NotFoundException('Contacto de emergencia no encontrado');
        }
        if (updateDto.primary) {
            await this.prisma.emergency_contacts.updateMany({
                where: {
                    owner_id: userId,
                    active: true,
                    emergency_id: { not: contactId },
                },
                data: {
                    primary: false,
                },
            });
        }
        const updatedContact = await this.prisma.emergency_contacts.update({
            where: { emergency_id: contactId },
            data: updateDto,
        });
        this.logger.log(`Emergency contact updated: ${contactId}`);
        return {
            status: 'success',
            data: updatedContact,
            message: 'Contacto actualizado exitosamente',
        };
    }
    async remove(contactId, userId) {
        const contact = await this.prisma.emergency_contacts.findFirst({
            where: {
                emergency_id: contactId,
                owner_id: userId,
                active: true,
            },
        });
        if (!contact) {
            throw new common_1.NotFoundException('Contacto de emergencia no encontrado');
        }
        await this.prisma.emergency_contacts.update({
            where: { emergency_id: contactId },
            data: { active: false },
        });
        this.logger.log(`Emergency contact deleted (soft): ${contactId}`);
        return {
            status: 'success',
            message: 'Contacto eliminado exitosamente',
        };
    }
};
exports.EmergencyContactsService = EmergencyContactsService;
exports.EmergencyContactsService = EmergencyContactsService = EmergencyContactsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], EmergencyContactsService);
//# sourceMappingURL=emergency-contacts.service.js.map