import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import { CreateLegalRepresentativeDto } from './dto/create-legal-representative.dto';
import { UpdateLegalRepresentativeDto } from './dto/update-legal-representative.dto';

@Injectable()
export class LegalRepresentativesService {
  private readonly logger = new Logger(LegalRepresentativesService.name);

  constructor(
    private prisma: PrismaService,
    private usersService: UsersService,
  ) {}

  async create(userId: string, createDto: CreateLegalRepresentativeDto) {
    // Validar que el usuario requiere representante legal
    const requiresRep =
      await this.usersService.requiresLegalRepresentative(userId);

    if (!requiresRep) {
      throw new BadRequestException(
        'Usuario mayor de 18 años no requiere representante legal',
      );
    }

    // Validar que no tenga ya un representante
    const existing = await this.prisma.legal_representatives.findUnique({
      where: { user_id: userId },
    });

    if (existing) {
      throw new ConflictException('El usuario ya tiene un representante legal');
    }

    // Validar que se proporcione usuario registrado O datos manuales
    if (
      !createDto.representative_user_id &&
      (!createDto.name || !createDto.paternal_last_name || !createDto.phone)
    ) {
      throw new BadRequestException(
        'Debe proporcionar representative_user_id O los datos completos (name, paternal_last_name, phone)',
      );
    }

    // Si es usuario registrado, verificar que exista
    if (createDto.representative_user_id) {
      const repUser = await this.prisma.users.findUnique({
        where: { user_id: createDto.representative_user_id },
      });

      if (!repUser) {
        throw new NotFoundException('Usuario representante no encontrado');
      }
    }

    // Verificar que el relationship_type existe
    const relType = await this.prisma.relationship_types.findUnique({
      where: { relationship_type_id: createDto.relationship_type_id },
    });

    if (!relType) {
      throw new NotFoundException('Tipo de relación no encontrado');
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

  async findOne(userId: string) {
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
      throw new NotFoundException('Representante legal no encontrado');
    }

    return { status: 'success', data: representative };
  }

  async update(
    userId: string,
    updateDto: UpdateLegalRepresentativeDto,
  ) {
    // Verificar que existe
    const existing = await this.prisma.legal_representatives.findUnique({
      where: { user_id: userId },
    });

    if (!existing) {
      throw new NotFoundException('Representante legal no encontrado');
    }

    // Si actualizan representative_user_id, verificar que existe
    if (updateDto.representative_user_id) {
      const repUser = await this.prisma.users.findUnique({
        where: { user_id: updateDto.representative_user_id },
      });

      if (!repUser) {
        throw new NotFoundException('Usuario representante no encontrado');
      }
    }

    // Si actualizan relationship_type_id, verificar que existe
    if (updateDto.relationship_type_id) {
      const relType = await this.prisma.relationship_types.findUnique({
        where: { relationship_type_id: updateDto.relationship_type_id },
      });

      if (!relType) {
        throw new NotFoundException('Tipo de relación no encontrado');
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

  async remove(userId: string) {
    const existing = await this.prisma.legal_representatives.findUnique({
      where: { user_id: userId },
    });

    if (!existing) {
      throw new NotFoundException('Representante legal no encontrado');
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
}
