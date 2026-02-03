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
var PostRegistrationService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.PostRegistrationService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
const users_service_1 = require("../users/users.service");
const legal_representatives_service_1 = require("../legal-representatives/legal-representatives.service");
let PostRegistrationService = PostRegistrationService_1 = class PostRegistrationService {
    prisma;
    usersService;
    legalRepService;
    logger = new common_1.Logger(PostRegistrationService_1.name);
    constructor(prisma, usersService, legalRepService) {
        this.prisma = prisma;
        this.usersService = usersService;
        this.legalRepService = legalRepService;
    }
    async getStatus(userId) {
        const userPr = await this.prisma.users_pr.findUnique({
            where: { user_id: userId },
        });
        if (!userPr) {
            throw new common_1.BadRequestException('Post-registro no iniciado');
        }
        let nextStep = null;
        if (!userPr.profile_picture_complete) {
            nextStep = 'profilePicture';
        }
        else if (!userPr.personal_info_complete) {
            nextStep = 'personalInfo';
        }
        else if (!userPr.club_selection_complete) {
            nextStep = 'clubSelection';
        }
        return {
            status: 'success',
            data: {
                complete: userPr.complete,
                steps: {
                    profilePicture: userPr.profile_picture_complete,
                    personalInfo: userPr.personal_info_complete,
                    clubSelection: userPr.club_selection_complete,
                },
                nextStep,
                dateCompleted: userPr.date_completed,
            },
        };
    }
    async completeStep1(userId) {
        const user = await this.prisma.users.findUnique({
            where: { user_id: userId },
            select: { user_image: true },
        });
        if (!user?.user_image) {
            throw new common_1.BadRequestException('Debe subir una foto de perfil antes de completar este paso');
        }
        await this.prisma.users_pr.update({
            where: { user_id: userId },
            data: { profile_picture_complete: true },
        });
        this.logger.log(`Step 1 (profile picture) completed for user ${userId}`);
        return {
            status: 'success',
            message: 'Paso 1 completado: Foto de perfil',
        };
    }
    async completeStep2(userId) {
        const user = await this.prisma.users.findUnique({
            where: { user_id: userId },
            select: {
                gender: true,
                birthday: true,
                baptism: true,
            },
        });
        if (!user) {
            throw new common_1.BadRequestException('Usuario no encontrado');
        }
        if (!user.gender || !user.birthday || user.baptism === null) {
            throw new common_1.BadRequestException('Debe completar información personal (género, cumpleaños, bautismo)');
        }
        const contactsCount = await this.prisma.emergency_contacts.count({
            where: {
                owner_id: userId,
                active: true,
            },
        });
        if (contactsCount === 0) {
            throw new common_1.BadRequestException('Debe agregar al menos un contacto de emergencia');
        }
        const requiresRep = await this.usersService.requiresLegalRepresentative(userId);
        if (requiresRep) {
            try {
                await this.legalRepService.findOne(userId);
            }
            catch {
                throw new common_1.BadRequestException('Menores de 18 años deben registrar un representante legal');
            }
        }
        await this.prisma.users_pr.update({
            where: { user_id: userId },
            data: { personal_info_complete: true },
        });
        this.logger.log(`Step 2 (personal info) completed for user ${userId}`);
        return {
            status: 'success',
            message: 'Paso 2 completado: Información personal',
        };
    }
    async completeStep3(userId, dto) {
        return await this.prisma.$transaction(async (tx) => {
            await tx.users.update({
                where: { user_id: userId },
                data: {
                    country_id: dto.country_id,
                    union_id: dto.union_id,
                    local_field_id: dto.local_field_id,
                },
            });
            const currentYear = await tx.ecclesiastical_years.findFirst({
                where: {
                    start_date: { lte: new Date() },
                    end_date: { gte: new Date() },
                },
            });
            if (!currentYear) {
                throw new common_1.InternalServerErrorException('No hay año eclesiástico activo configurado');
            }
            const memberRole = await tx.roles.findFirst({
                where: {
                    role_name: 'member',
                    role_category: 'CLUB',
                },
            });
            if (!memberRole) {
                throw new common_1.InternalServerErrorException('Rol "member" no encontrado en el sistema');
            }
            const clubInstanceField = dto.club_type === 'adventurers'
                ? 'club_adv_id'
                : dto.club_type === 'pathfinders'
                    ? 'club_pathf_id'
                    : 'club_mg_id';
            const clubTable = dto.club_type === 'adventurers'
                ? 'club_adventurers'
                : dto.club_type === 'pathfinders'
                    ? 'club_pathfinders'
                    : 'club_master_guilds';
            const clubIdField = dto.club_type === 'adventurers'
                ? 'club_adv_id'
                : dto.club_type === 'pathfinders'
                    ? 'club_pathf_id'
                    : 'club_mg_id';
            const club = await tx[clubTable].findUnique({
                where: { [clubIdField]: dto.club_instance_id },
            });
            if (!club) {
                throw new common_1.BadRequestException('Club no encontrado');
            }
            await tx.club_role_assignments.create({
                data: {
                    user_id: userId,
                    role_id: memberRole.role_id,
                    [clubInstanceField]: dto.club_instance_id,
                    ecclesiastical_year_id: currentYear.year_id,
                    start_date: new Date(),
                    active: true,
                    status: 'active',
                },
            });
            await tx.users_classes.create({
                data: {
                    user_id: userId,
                    class_id: dto.class_id,
                    current_class: true,
                },
            });
            await tx.users_pr.update({
                where: { user_id: userId },
                data: {
                    club_selection_complete: true,
                    complete: true,
                    date_completed: new Date(),
                },
            });
            this.logger.log(`Step 3 (club selection) completed for user ${userId} - Post-registration COMPLETE`);
            return {
                status: 'success',
                message: 'Post-registro completado exitosamente',
                data: {
                    clubType: dto.club_type,
                    clubId: dto.club_instance_id,
                    classId: dto.class_id,
                    ecclesiasticalYear: currentYear.year_id,
                },
            };
        });
    }
};
exports.PostRegistrationService = PostRegistrationService;
exports.PostRegistrationService = PostRegistrationService = PostRegistrationService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        users_service_1.UsersService,
        legal_representatives_service_1.LegalRepresentativesService])
], PostRegistrationService);
//# sourceMappingURL=post-registration.service.js.map