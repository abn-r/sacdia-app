import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../../prisma/prisma.service';

export const CLUB_ROLES_KEY = 'club_roles';

export type ClubRoleType =
  | 'director'
  | 'subdirector'
  | 'secretary'
  | 'treasurer'
  | 'counselor'
  | 'instructor'
  | 'captain'
  | 'member';

@Injectable()
export class ClubRolesGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredRoles = this.reflector.getAllAndOverride<ClubRoleType[]>(
      CLUB_ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );

    // Si no se requieren roles específicos, permitir
    if (!requiredRoles || requiredRoles.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user || !user.sub) {
      throw new ForbiddenException('User not authenticated');
    }

    // Obtener el clubId del request (params o body)
    const clubId = this.extractClubId(request);

    if (!clubId) {
      throw new ForbiddenException('Club ID not found in request');
    }

    // Verificar si el usuario tiene alguno de los roles requeridos en el club
    const hasRole = await this.checkUserClubRole(
      user.sub,
      clubId,
      requiredRoles,
    );

    if (!hasRole) {
      throw new ForbiddenException(
        `You need one of these club roles: ${requiredRoles.join(', ')}`,
      );
    }

    return true;
  }

  private extractClubId(request: any): number | null {
    // Intentar obtener de params
    if (request.params?.clubId) {
      return parseInt(request.params.clubId, 10);
    }

    // Intentar obtener de body
    if (request.body?.club_id) {
      return parseInt(request.body.club_id, 10);
    }

    // Intentar obtener de query
    if (request.query?.clubId) {
      return parseInt(request.query.clubId, 10);
    }

    return null;
  }

  private async checkUserClubRole(
    userId: string,
    clubId: number,
    requiredRoles: ClubRoleType[],
  ): Promise<boolean> {
    // Primero, obtener el club y sus instancias
    const club = await this.prisma.clubs.findUnique({
      where: { club_id: clubId },
      select: {
        club_adventurers: { select: { club_adv_id: true } },
        club_pathfinders: { select: { club_pathf_id: true } },
        club_master_guild: { select: { club_mg_id: true } },
      },
    });

    if (!club) {
      return false;
    }

    // Obtener IDs de instancias
    const advIds = club.club_adventurers.map((a) => a.club_adv_id);
    const pathfIds = club.club_pathfinders.map((p) => p.club_pathf_id);
    const mgIds = club.club_master_guild.map((m) => m.club_mg_id);

    // Buscar asignaciones activas del usuario en cualquiera de las instancias
    const assignments = await this.prisma.club_role_assignments.findMany({
      where: {
        user_id: userId,
        active: true,
        status: 'active',
        OR: [
          { club_adv_id: { in: advIds.length > 0 ? advIds : [-1] } },
          { club_pathf_id: { in: pathfIds.length > 0 ? pathfIds : [-1] } },
          { club_mg_id: { in: mgIds.length > 0 ? mgIds : [-1] } },
        ],
      },
      include: {
        roles: { select: { role_name: true } },
      },
    });

    // Verificar si alguno de los roles del usuario coincide con los requeridos
    const userRoleNames = assignments.map((a) =>
      a.roles.role_name.toLowerCase(),
    );

    return requiredRoles.some((requiredRole) =>
      userRoleNames.includes(requiredRole.toLowerCase()),
    );
  }
}
