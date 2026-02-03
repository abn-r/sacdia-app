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
var AuthService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
const supabase_service_1 = require("../common/supabase.service");
let AuthService = AuthService_1 = class AuthService {
    prisma;
    supabase;
    logger = new common_1.Logger(AuthService_1.name);
    constructor(prisma, supabase) {
        this.prisma = prisma;
        this.supabase = supabase;
    }
    async register(dto) {
        return await this.prisma.$transaction(async (tx) => {
            const { data: authUser, error: authError } = await this.supabase.admin.auth.admin.createUser({
                email: dto.email,
                password: dto.password,
                email_confirm: true,
            });
            if (authError) {
                this.logger.error(`Supabase auth error: ${authError.message}`, authError);
                throw new common_1.BadRequestException(authError.message);
            }
            try {
                const user = await tx.users.create({
                    data: {
                        user_id: authUser.user.id,
                        email: dto.email,
                        name: dto.name,
                        paternal_last_name: dto.paternal_last_name,
                        maternal_last_name: dto.maternal_last_name,
                    },
                });
                await tx.users_pr.create({
                    data: {
                        user_id: user.user_id,
                        complete: false,
                        profile_picture_complete: false,
                        personal_info_complete: false,
                        club_selection_complete: false,
                    },
                });
                const userRole = await tx.roles.findFirst({
                    where: {
                        role_name: 'user',
                        role_category: 'GLOBAL',
                    },
                });
                if (!userRole) {
                    throw new common_1.InternalServerErrorException('User role not found');
                }
                await tx.users_roles.create({
                    data: {
                        user_id: user.user_id,
                        role_id: userRole.role_id,
                    },
                });
                this.logger.log(`User registered successfully: ${user.user_id}`);
                return {
                    success: true,
                    userId: user.user_id,
                    message: 'Usuario registrado exitosamente',
                };
            }
            catch (dbError) {
                this.logger.error('Database error, rolling back Supabase user', dbError);
                await this.supabase.admin.auth.admin.deleteUser(authUser.user.id);
                throw dbError;
            }
        });
    }
    async login(dto) {
        const { data, error } = await this.supabase.admin.auth.signInWithPassword({
            email: dto.email,
            password: dto.password,
        });
        if (error) {
            this.logger.warn(`Login failed for ${dto.email}: ${error.message}`);
            throw new common_1.UnauthorizedException('Credenciales inválidas');
        }
        const user = await this.prisma.users.findUnique({
            where: { user_id: data.user.id },
            select: {
                user_id: true,
                email: true,
                name: true,
                paternal_last_name: true,
                maternal_last_name: true,
                user_image: true,
                users_pr: {
                    select: {
                        complete: true,
                        profile_picture_complete: true,
                        personal_info_complete: true,
                        club_selection_complete: true,
                    },
                },
            },
        });
        if (!user) {
            throw new common_1.UnauthorizedException('Usuario no encontrado');
        }
        const needsPostRegistration = user.users_pr[0]
            ? !user.users_pr[0].complete
            : true;
        return {
            status: 'success',
            data: {
                accessToken: data.session.access_token,
                refreshToken: data.session.refresh_token,
                user: {
                    id: user.user_id,
                    email: user.email,
                    name: user.name,
                    paternal_last_name: user.paternal_last_name,
                    maternal_last_name: user.maternal_last_name,
                    avatar: user.user_image,
                },
                needsPostRegistration,
                postRegistrationStatus: user.users_pr[0] || null,
            },
        };
    }
    async logout(accessToken) {
        const { error } = await this.supabase.admin.auth.admin.signOut(accessToken);
        if (error) {
            this.logger.error(`Logout error: ${error.message}`, error);
            throw new common_1.InternalServerErrorException('Error al cerrar sesión');
        }
        return { success: true, message: 'Sesión cerrada exitosamente' };
    }
    async requestPasswordReset(dto) {
        const { error } = await this.supabase.admin.auth.resetPasswordForEmail(dto.email, {
            redirectTo: `${process.env.FRONTEND_URL}/reset-password`,
        });
        if (error) {
            this.logger.error(`Password reset request error: ${error.message}`, error);
            throw new common_1.BadRequestException('Error al solicitar recuperación');
        }
        this.logger.log(`Password reset requested for: ${dto.email}`);
        return {
            success: true,
            message: 'Correo de recuperación enviado',
        };
    }
    async getProfile(userId) {
        const user = await this.prisma.users.findUnique({
            where: { user_id: userId },
            select: {
                user_id: true,
                email: true,
                name: true,
                paternal_last_name: true,
                maternal_last_name: true,
                gender: true,
                birthday: true,
                baptism: true,
                baptism_date: true,
                user_image: true,
                country_id: true,
                union_id: true,
                local_field_id: true,
                created_at: true,
            },
        });
        if (!user) {
            throw new common_1.UnauthorizedException('Usuario no encontrado');
        }
        return { status: 'success', data: user };
    }
    async getCompletionStatus(userId) {
        const userPr = await this.prisma.users_pr.findUnique({
            where: { user_id: userId },
            select: {
                complete: true,
                profile_picture_complete: true,
                personal_info_complete: true,
                club_selection_complete: true,
                date_completed: true,
            },
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
};
exports.AuthService = AuthService;
exports.AuthService = AuthService = AuthService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        supabase_service_1.SupabaseService])
], AuthService);
//# sourceMappingURL=auth.service.js.map