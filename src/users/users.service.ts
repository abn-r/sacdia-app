import {
  Injectable,
  NotFoundException,
  BadRequestException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SupabaseService } from '../common/supabase.service';
import { UpdateUserDto } from './dto/update-user.dto';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    private prisma: PrismaService,
    private supabase: SupabaseService,
  ) {}

  async findOne(userId: string) {
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
      throw new NotFoundException('Usuario no encontrado');
    }

    return { status: 'success', data: user };
  }

  async update(userId: string, updateUserDto: UpdateUserDto) {
    // Validar que el usuario existe
    const existingUser = await this.prisma.users.findUnique({
      where: { user_id: userId },
    });

    if (!existingUser) {
      throw new NotFoundException('Usuario no encontrado');
    }

    // Validar baptism_date solo si baptism es true
    if (updateUserDto.baptism === false && updateUserDto.baptism_date) {
      throw new BadRequestException(
        'No se puede especificar fecha de bautismo si no está bautizado',
      );
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

  async uploadProfilePicture(userId: string, file: Express.Multer.File) {
    // Validar formato
    const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/webp'];
    if (!allowedMimeTypes.includes(file.mimetype)) {
      throw new BadRequestException(
        'Formato no válido. Solo se permiten JPG, PNG, WEBP',
      );
    }

    // Validar tamaño (max 5MB)
    const maxSize = 5 * 1024 * 1024; // 5MB
    if (file.size > maxSize) {
      throw new BadRequestException(
        'Archivo muy grande. Tamaño máximo: 5MB',
      );
    }

    // Determinar extensión
    const extension = file.mimetype.split('/')[1];
    const fileName = `photo-${userId}.${extension}`;

    // Upload a Supabase Storage
    const { error: uploadError } = await this.supabase.admin.storage
      .from('profile-pictures')
      .upload(fileName, file.buffer, {
        contentType: file.mimetype,
        upsert: true, // Sobrescribir si existe
      });

    if (uploadError) {
      this.logger.error('Supabase upload error:', uploadError);
      throw new InternalServerErrorException('Error al subir la imagen');
    }

    // Obtener URL pública
    const {
      data: { publicUrl },
    } = this.supabase.admin.storage
      .from('profile-pictures')
      .getPublicUrl(fileName);

    // Actualizar en BD
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

  async deleteProfilePicture(userId: string) {
    const user = await this.prisma.users.findUnique({
      where: { user_id: userId },
      select: { user_image: true },
    });

    if (!user) {
      throw new NotFoundException('Usuario no encontrado');
    }

    if (!user.user_image) {
      throw new BadRequestException('El usuario no tiene foto de perfil');
    }

    // Extraer nombre de archivo de la URL
    const fileName = user.user_image.split('/').pop();

    // Eliminar de Supabase Storage
    const { error } = await this.supabase.admin.storage
      .from('profile-pictures')
      .remove([fileName!]);

    if (error) {
      this.logger.error('Supabase delete error:', error);
      throw new InternalServerErrorException('Error al eliminar la imagen');
    }

    // Actualizar en BD
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

  async calculateAge(userId: string): Promise<number | null> {
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

    if (
      monthDiff < 0 ||
      (monthDiff === 0 && today.getDate() < birthDate.getDate())
    ) {
      age--;
    }

    return age;
  }

  async requiresLegalRepresentative(userId: string): Promise<boolean> {
    const age = await this.calculateAge(userId);
    return age !== null && age < 18;
  }
}
