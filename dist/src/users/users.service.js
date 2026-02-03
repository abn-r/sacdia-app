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
var UsersService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.UsersService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
const supabase_service_1 = require("../common/supabase.service");
let UsersService = UsersService_1 = class UsersService {
    prisma;
    supabase;
    logger = new common_1.Logger(UsersService_1.name);
    constructor(prisma, supabase) {
        this.prisma = prisma;
        this.supabase = supabase;
    }
    async findOne(userId) {
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
                blood: true,
                user_image: true,
                country_id: true,
                union_id: true,
                local_field_id: true,
                access_app: true,
                access_panel: true,
                created_at: true,
                modified_at: true,
            },
        });
        if (!user) {
            throw new common_1.NotFoundException('Usuario no encontrado');
        }
        return { status: 'success', data: user };
    }
    async update(userId, updateUserDto) {
        const existingUser = await this.prisma.users.findUnique({
            where: { user_id: userId },
        });
        if (!existingUser) {
            throw new common_1.NotFoundException('Usuario no encontrado');
        }
        if (updateUserDto.baptism === false && updateUserDto.baptism_date) {
            throw new common_1.BadRequestException('No se puede especificar fecha de bautismo si no está bautizado');
        }
        const updatedUser = await this.prisma.users.update({
            where: { user_id: userId },
            data: updateUserDto,
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
                blood: true,
                modified_at: true,
            },
        });
        this.logger.log(`User updated: ${userId}`);
        return {
            status: 'success',
            data: updatedUser,
            message: 'Usuario actualizado exitosamente',
        };
    }
    async uploadProfilePicture(userId, file) {
        const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/webp'];
        if (!allowedMimeTypes.includes(file.mimetype)) {
            throw new common_1.BadRequestException('Formato no válido. Solo se permiten JPG, PNG, WEBP');
        }
        const maxSize = 5 * 1024 * 1024;
        if (file.size > maxSize) {
            throw new common_1.BadRequestException('Archivo muy grande. Tamaño máximo: 5MB');
        }
        const extension = file.mimetype.split('/')[1];
        const fileName = `photo-${userId}.${extension}`;
        const { error: uploadError } = await this.supabase.admin.storage
            .from('profile-pictures')
            .upload(fileName, file.buffer, {
            contentType: file.mimetype,
            upsert: true,
        });
        if (uploadError) {
            this.logger.error('Supabase upload error:', uploadError);
            throw new common_1.InternalServerErrorException('Error al subir la imagen');
        }
        const { data: { publicUrl }, } = this.supabase.admin.storage
            .from('profile-pictures')
            .getPublicUrl(fileName);
        await this.prisma.users.update({
            where: { user_id: userId },
            data: { user_image: publicUrl },
        });
        this.logger.log(`Profile picture uploaded for user: ${userId}`);
        return {
            status: 'success',
            data: {
                url: publicUrl,
                fileName,
            },
            message: 'Foto de perfil actualizada exitosamente',
        };
    }
    async deleteProfilePicture(userId) {
        const user = await this.prisma.users.findUnique({
            where: { user_id: userId },
            select: { user_image: true },
        });
        if (!user) {
            throw new common_1.NotFoundException('Usuario no encontrado');
        }
        if (!user.user_image) {
            throw new common_1.BadRequestException('El usuario no tiene foto de perfil');
        }
        const fileName = user.user_image.split('/').pop();
        const { error } = await this.supabase.admin.storage
            .from('profile-pictures')
            .remove([fileName]);
        if (error) {
            this.logger.error('Supabase delete error:', error);
            throw new common_1.InternalServerErrorException('Error al eliminar la imagen');
        }
        await this.prisma.users.update({
            where: { user_id: userId },
            data: { user_image: null },
        });
        this.logger.log(`Profile picture deleted for user: ${userId}`);
        return {
            status: 'success',
            message: 'Foto de perfil eliminada exitosamente',
        };
    }
    async calculateAge(userId) {
        const user = await this.prisma.users.findUnique({
            where: { user_id: userId },
            select: { birthday: true },
        });
        if (!user || !user.birthday) {
            return null;
        }
        const today = new Date();
        const birthDate = new Date(user.birthday);
        let age = today.getFullYear() - birthDate.getFullYear();
        const monthDiff = today.getMonth() - birthDate.getMonth();
        if (monthDiff < 0 ||
            (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
            age--;
        }
        return age;
    }
    async requiresLegalRepresentative(userId) {
        const age = await this.calculateAge(userId);
        return age !== null && age < 18;
    }
};
exports.UsersService = UsersService;
exports.UsersService = UsersService = UsersService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        supabase_service_1.SupabaseService])
], UsersService);
//# sourceMappingURL=users.service.js.map