import {
  Injectable,
  BadRequestException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import { LegalRepresentativesService } from '../legal-representatives/legal-representatives.service';
import { CompleteClubSelectionDto } from './dto/complete-club-selection.dto';

@Injectable()
export class PostRegistrationService {
  private readonly logger = new Logger(PostRegistrationService.name);

  constructor(
    private prisma: PrismaService,
    private usersService: UsersService,
    private legalRepService: LegalRepresentativesService,
  ) {}

  async getStatus(userId: string) {
    const userPr = await this.prisma.users_pr.findUnique({
      where: { user_id: userId },
    });

    if (!userPr) {
      throw new BadRequestException('Post-registro no iniciado');
    }

    let nextStep: string | null = null;
    if (!userPr.profile_picture_complete) {
      nextStep = 'profilePicture';
    } else if (!userPr.personal_info_complete) {
      nextStep = 'personalInfo';
    } else if (!userPr.club_selection_complete) {
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

  async completeStep1(userId: string) {
    // Verificar que el usuario tenga foto
    const user = await this.prisma.users.findUnique({
      where: { user_id: userId },
      select: { user_image: true },
    });

    if (!user?.user_image) {
      throw new BadRequestException(
        'Debe subir una foto de perfil antes de completar este paso',
      );
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

  async completeStep2(userId: string) {
    // Validar que tenga info personal completa
    const user = await this.prisma.users.findUnique({
      where: { user_id: userId },
      select: {
        gender: true,
        birthday: true,
        baptism: true,
      },
    });

    if (!user) {
      throw new BadRequestException('Usuario no encontrado');
    }

    if (!user.gender || !user.birthday || user.baptism === null) {
      throw new BadRequestException(
        'Debe completar información personal (género, cumpleaños, bautismo)',
      );
    }

    // Validar contactos de emergencia (al menos 1)
    const contactsCount = await this.prisma.emergency_contacts.count({
      where: {
        owner_id: userId,
        active: true,
      },
    });

    if (contactsCount === 0) {
      throw new BadRequestException(
        'Debe agregar al menos un contacto de emergencia',
      );
    }

    // Si es menor de 18, validar representante legal
    const requiresRep =
      await this.usersService.requiresLegalRepresentative(userId);

    if (requiresRep) {
      try {
        await this.legalRepService.findOne(userId);
      } catch {
        throw new BadRequestException(
          'Menores de 18 años deben registrar un representante legal',
        );
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

  async completeStep3(userId: string, dto: CompleteClubSelectionDto) {
    return await this.prisma.$transaction(async (tx) => {
      // 1. Actualizar país, unión, campo local
      await tx.users.update({
        where: { user_id: userId },
        data: {
          country_id: dto.country_id,
          union_id: dto.union_id,
          local_field_id: dto.local_field_id,
        },
      });

      // 2. Obtener año eclesiástico actual
      const currentYear = await tx.ecclesiastical_years.findFirst({
        where: {
          start_date: { lte: new Date() },
          end_date: { gte: new Date() },
        },
      });

      if (!currentYear) {
        throw new InternalServerErrorException(
          'No hay año eclesiástico activo configurado',
        );
      }

      // 3. Obtener rol "member" (CLUB)
      const memberRole = await tx.roles.findFirst({
        where: {
          role_name: 'member',
          role_category: 'CLUB',
        },
      });

      if (!memberRole) {
        throw new InternalServerErrorException(
          'Rol "member" no encontrado en el sistema',
        );
      }

      // 4. Determinar campo de instancia según tipo de club
      const clubInstanceField =
        dto.club_type === 'adventurers'
          ? 'club_adv_id'
          : dto.club_type === 'pathfinders'
            ? 'club_pathf_id'
            : 'club_mg_id';

      // 5. Verificar que el club existe
      const clubTable =
        dto.club_type === 'adventurers'
          ? 'club_adventurers'
          : dto.club_type === 'pathfinders'
            ? 'club_pathfinders'
            : 'club_master_guilds';

      const clubIdField =
        dto.club_type === 'adventurers'
          ? 'club_adv_id'
          : dto.club_type === 'pathfinders'
            ? 'club_pathf_id'
            : 'club_mg_id';

      const club = await (tx as any)[clubTable].findUnique({
        where: { [clubIdField]: dto.club_instance_id },
      });

      if (!club) {
        throw new BadRequestException('Club no encontrado');
      }

      // 6. Asignar rol en club
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

      // 7. Inscribir en clase
      await tx.users_classes.create({
        data: {
          user_id: userId,
          class_id: dto.class_id,
          current_class: true,
        },
      });

      // 8. Marcar post-registro completo
      await tx.users_pr.update({
        where: { user_id: userId },
        data: {
          club_selection_complete: true,
          complete: true,
          date_completed: new Date(),
        },
      });

      this.logger.log(
        `Step 3 (club selection) completed for user ${userId} - Post-registration COMPLETE`,
      );

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
}
