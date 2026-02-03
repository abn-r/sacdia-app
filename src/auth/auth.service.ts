import {
  Injectable,
  BadRequestException,
  UnauthorizedException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SupabaseService } from '../common/supabase.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { ResetPasswordRequestDto } from './dto/reset-password-request.dto';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private prisma: PrismaService,
    private supabase: SupabaseService,
  ) {}

  async register(dto: RegisterDto) {
    return await this.prisma.$transaction(async (tx) => {
      // 1. Crear usuario en Supabase Auth
      const { data: authUser, error: authError } =
        await this.supabase.admin.auth.admin.createUser({
          email: dto.email,
          password: dto.password,
          email_confirm: true, // Auto-confirmar email
        });

      if (authError) {
        this.logger.error(
          `Supabase auth error: ${authError.message}`,
          authError,
        );
        throw new BadRequestException(authError.message);
      }

      try {
        // 2. Crear en tabla users
        const user = await tx.users.create({
          data: {
            user_id: authUser.user.id,
            email: dto.email,
            name: dto.name,
            paternal_last_name: dto.paternal_last_name,
            maternal_last_name: dto.maternal_last_name,
          },
        });

        // 3. Crear en users_pr con tracking granular
        await tx.users_pr.create({
          data: {
            user_id: user.user_id,
            complete: false,
            profile_picture_complete: false,
            personal_info_complete: false,
            club_selection_complete: false,
          },
        });

        // 4. Asignar rol "user" (GLOBAL)
        const userRole = await tx.roles.findFirst({
          where: {
            role_name: 'user',
            role_category: 'GLOBAL',
          },
        });

        if (!userRole) {
          throw new InternalServerErrorException('User role not found');
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
      } catch (dbError) {
        // Rollback: Eliminar usuario de Supabase si falla BD
        this.logger.error('Database error, rolling back Supabase user', dbError);
        await this.supabase.admin.auth.admin.deleteUser(authUser.user.id);
        throw dbError;
      }
    });
  }

  async login(dto: LoginDto) {
    // 1. Autenticar con Supabase
    const { data, error } =
      await this.supabase.admin.auth.signInWithPassword({
        email: dto.email,
        password: dto.password,
      });

    if (error) {
      this.logger.warn(`Login failed for ${dto.email}: ${error.message}`);
      throw new UnauthorizedException('Credenciales inválidas');
    }

    // 2. Obtener información del usuario y verificar post-registro
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
      throw new UnauthorizedException('Usuario no encontrado');
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

  async logout(accessToken: string) {
    const { error } = await this.supabase.admin.auth.admin.signOut(
      accessToken,
    );

    if (error) {
      this.logger.error(`Logout error: ${error.message}`, error);
      throw new InternalServerErrorException('Error al cerrar sesión');
    }

    return { success: true, message: 'Sesión cerrada exitosamente' };
  }

  async requestPasswordReset(dto: ResetPasswordRequestDto) {
    const { error } = await this.supabase.admin.auth.resetPasswordForEmail(
      dto.email,
      {
        redirectTo: `${process.env.FRONTEND_URL}/reset-password`,
      },
    );

    if (error) {
      this.logger.error(
        `Password reset request error: ${error.message}`,
        error,
      );
      throw new BadRequestException('Error al solicitar recuperación');
    }

    this.logger.log(`Password reset requested for: ${dto.email}`);

    return {
      success: true,
      message: 'Correo de recuperación enviado',
    };
  }

  async getProfile(userId: string) {
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
      throw new UnauthorizedException('Usuario no encontrado');
    }

    return { status: 'success', data: user };
  }

  async getCompletionStatus(userId: string) {
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
}
