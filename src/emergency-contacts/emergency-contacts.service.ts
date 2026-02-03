import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateEmergencyContactDto } from './dto/create-emergency-contact.dto';
import { UpdateEmergencyContactDto } from './dto/update-emergency-contact.dto';

@Injectable()
export class EmergencyContactsService {
  private readonly logger = new Logger(EmergencyContactsService.name);
  private readonly MAX_CONTACTS = 5;

  constructor(private prisma: PrismaService) {}

  async create(userId: string, createDto: CreateEmergencyContactDto) {
    // Validar máximo 5 contactos activos
    const activeCount = await this.prisma.emergency_contacts.count({
      where: {
        owner_id: userId,
        active: true,
      },
    });

    if (activeCount >= this.MAX_CONTACTS) {
      throw new BadRequestException(
        `Máximo ${this.MAX_CONTACTS} contactos de emergencia permitidos`,
      );
    }

    // Validar que no exista duplicado (mismo nombre y teléfono)
    const duplicate = await this.prisma.emergency_contacts.findFirst({
      where: {
        owner_id: userId,
        name: createDto.name,
        phone: createDto.phone,
        active: true,
      },
    });

    if (duplicate) {
      throw new ConflictException('Este contacto ya existe');
    }

    // Si marcan como principal, desmarcar otros
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

  async findAll(userId: string) {
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

  async findOne(contactId: number, userId: string) {
    const contact = await this.prisma.emergency_contacts.findFirst({
      where: {
        emergency_id: contactId,
        owner_id: userId,
        active: true,
      },
    });

    if (!contact) {
      throw new NotFoundException('Contacto de emergencia no encontrado');
    }

    return { status: 'success', data: contact };
  }

  async update(
    contactId: number,
    userId: string,
    updateDto: UpdateEmergencyContactDto,
  ) {
    // Verificar que el contacto existe y pertenece al usuario
    const existingContact = await this.prisma.emergency_contacts.findFirst({
      where: {
        emergency_id: contactId,
        owner_id: userId,
        active: true,
      },
    });

    if (!existingContact) {
      throw new NotFoundException('Contacto de emergencia no encontrado');
    }

    // Si marcan como principal, desmarcar otros
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

  async remove(contactId: number, userId: string) {
    // Verificar que existe
    const contact = await this.prisma.emergency_contacts.findFirst({
      where: {
        emergency_id: contactId,
        owner_id: userId,
        active: true,
      },
    });

    if (!contact) {
      throw new NotFoundException('Contacto de emergencia no encontrado');
    }

    // Soft delete
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
}
