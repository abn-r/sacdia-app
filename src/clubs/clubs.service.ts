import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import {
  CreateClubDto,
  UpdateClubDto,
  CreateInstanceDto,
  UpdateInstanceDto,
  AssignRoleDto,
  UpdateRoleAssignmentDto,
  ClubInstanceType,
} from './dto';
import {
  PaginationDto,
  PaginatedResult,
  createPaginatedResult,
} from '../common/dto/pagination.dto';

@Injectable()
export class ClubsService {
  constructor(private readonly prisma: PrismaService) {}

  // ========================================
  // CLUBS - CRUD
  // ========================================

  async findAll(
    filters?: {
      localFieldId?: number;
      districtId?: number;
      churchId?: number;
      active?: boolean;
    },
    pagination?: PaginationDto,
  ): Promise<PaginatedResult<any>> {
    const where = {
      ...(filters?.localFieldId && { local_field_id: filters.localFieldId }),
      ...(filters?.districtId && {
        districlub_type_id: filters.districtId,
      }),
      ...(filters?.churchId && { church_id: filters.churchId }),
      ...(filters?.active !== undefined && { active: filters.active }),
    };

    const [data, total] = await Promise.all([
      this.prisma.clubs.findMany({
        where,
        include: {
          churches: { select: { name: true } },
          districts: { select: { name: true } },
          local_fields: { select: { name: true } },
          club_adventurers: { select: { club_adv_id: true, active: true } },
          club_pathfinders: { select: { club_pathf_id: true, active: true } },
          club_master_guild: { select: { club_mg_id: true, active: true } },
        },
        orderBy: { name: 'asc' },
        skip: pagination?.skip ?? 0,
        take: pagination?.take ?? 20,
      }),
      this.prisma.clubs.count({ where }),
    ]);

    return createPaginatedResult(
      data,
      total,
      pagination ?? new PaginationDto(),
    );
  }

  async findOne(clubId: number) {
    const club = await this.prisma.clubs.findUnique({
      where: { club_id: clubId },
      include: {
        churches: true,
        districts: true,
        local_fields: true,
        club_adventurers: true,
        club_pathfinders: true,
        club_master_guild: true,
      },
    });

    if (!club) {
      throw new NotFoundException(`Club with ID ${clubId} not found`);
    }

    return club;
  }

  async create(dto: CreateClubDto) {
    return this.prisma.clubs.create({
      data: {
        name: dto.name,
        description: dto.description,
        local_field_id: dto.local_field_id,
        districlub_type_id: dto.districlub_type_id,
        church_id: dto.church_id,
        address: dto.address,
        coordinates: dto.coordinates || { lat: 0, lng: 0 },
        active: true,
      },
    });
  }

  async update(clubId: number, dto: UpdateClubDto) {
    await this.findOne(clubId); // Verify exists

    return this.prisma.clubs.update({
      where: { club_id: clubId },
      data: {
        ...dto,
        modified_at: new Date(),
      },
    });
  }

  async remove(clubId: number) {
    await this.findOne(clubId);

    return this.prisma.clubs.update({
      where: { club_id: clubId },
      data: { active: false, modified_at: new Date() },
    });
  }

  // ========================================
  // INSTANCES (Adventurers, Pathfinders, Master Guilds)
  // ========================================

  async getInstances(clubId: number) {
    const club = await this.findOne(clubId);

    return {
      adventurers: club.club_adventurers,
      pathfinders: club.club_pathfinders,
      master_guilds: club.club_master_guild,
    };
  }

  async getInstance(clubId: number, type: ClubInstanceType) {
    const club = await this.findOne(clubId);

    switch (type) {
      case ClubInstanceType.ADVENTURERS:
        return club.club_adventurers;
      case ClubInstanceType.PATHFINDERS:
        return club.club_pathfinders;
      case ClubInstanceType.MASTER_GUILDS:
        return club.club_master_guild;
      default:
        throw new BadRequestException(`Invalid instance type: ${type}`);
    }
  }

  async createInstance(clubId: number, dto: CreateInstanceDto) {
    await this.findOne(clubId); // Verify club exists

    // Get club type id
    const clubType = await this.prisma.club_types.findFirst({
      where: {
        name: this.getClubTypeName(dto.type),
        active: true,
      },
    });

    if (!clubType) {
      throw new BadRequestException(
        `Club type for ${dto.type} not found in catalog`,
      );
    }

    // Cast meeting arrays to Prisma InputJsonValue
    const meetingDay = (dto.meeting_day || []) as Prisma.InputJsonValue[];
    const meetingTime = (dto.meeting_time || []) as Prisma.InputJsonValue[];

    switch (dto.type) {
      case ClubInstanceType.ADVENTURERS:
        return this.prisma.club_adventurers.create({
          data: {
            main_club_id: clubId,
            club_type_id: clubType.club_type_id,
            souls_target: dto.souls_target || 1,
            fee: dto.fee || 0,
            meeting_day: meetingDay,
            meeting_time: meetingTime,
            active: true,
          },
        });
      case ClubInstanceType.PATHFINDERS:
        return this.prisma.club_pathfinders.create({
          data: {
            main_club_id: clubId,
            club_type_id: clubType.club_type_id,
            souls_target: dto.souls_target || 1,
            fee: dto.fee || 0,
            meeting_day: meetingDay,
            meeting_time: meetingTime,
            active: true,
          },
        });
      case ClubInstanceType.MASTER_GUILDS:
        return this.prisma.club_master_guilds.create({
          data: {
            main_club_id: clubId,
            club_type_id: clubType.club_type_id,
            souls_target: dto.souls_target || 1,
            fee: dto.fee || 0,
            meeting_day: meetingDay,
            meeting_time: meetingTime,
            active: true,
          },
        });
      default:
        throw new BadRequestException(`Invalid instance type: ${dto.type}`);
    }
  }

  async updateInstance(
    instanceId: number,
    type: ClubInstanceType,
    dto: UpdateInstanceDto,
  ) {
    // Build update data with proper types
    const updateData: {
      souls_target?: number;
      fee?: number;
      meeting_day?: Prisma.InputJsonValue[];
      meeting_time?: Prisma.InputJsonValue[];
      active?: boolean;
      modified_at: Date;
    } = {
      modified_at: new Date(),
    };

    if (dto.souls_target !== undefined) updateData.souls_target = dto.souls_target;
    if (dto.fee !== undefined) updateData.fee = dto.fee;
    if (dto.active !== undefined) updateData.active = dto.active;
    if (dto.meeting_day) updateData.meeting_day = dto.meeting_day as Prisma.InputJsonValue[];
    if (dto.meeting_time) updateData.meeting_time = dto.meeting_time as Prisma.InputJsonValue[];

    switch (type) {
      case ClubInstanceType.ADVENTURERS:
        return this.prisma.club_adventurers.update({
          where: { club_adv_id: instanceId },
          data: updateData,
        });
      case ClubInstanceType.PATHFINDERS:
        return this.prisma.club_pathfinders.update({
          where: { club_pathf_id: instanceId },
          data: updateData,
        });
      case ClubInstanceType.MASTER_GUILDS:
        return this.prisma.club_master_guilds.update({
          where: { club_mg_id: instanceId },
          data: updateData,
        });
      default:
        throw new BadRequestException(`Invalid instance type: ${type}`);
    }
  }

  // ========================================
  // ROLE ASSIGNMENTS
  // ========================================

  async getMembers(instanceId: number, type: ClubInstanceType) {
    const whereClause = this.getInstanceWhereClause(instanceId, type);

    return this.prisma.club_role_assignments.findMany({
      where: {
        ...whereClause,
        active: true,
      },
      include: {
        users: {
          select: {
            user_id: true,
            name: true,
            paternal_last_name: true,
            maternal_last_name: true,
            user_image: true,
          },
        },
        roles: {
          select: {
            role_id: true,
            role_name: true,
            role_category: true,
          },
        },
      },
      orderBy: { start_date: 'desc' },
    });
  }

  async assignRole(dto: AssignRoleDto) {
    const assignment = {
      user_id: dto.user_id,
      role_id: dto.role_id,
      ecclesiastical_year_id: dto.ecclesiastical_year_id,
      start_date: dto.start_date,
      end_date: dto.end_date,
      active: true,
      status: 'active',
      club_adv_id:
        dto.instance_type === ClubInstanceType.ADVENTURERS
          ? dto.instance_id
          : null,
      club_pathf_id:
        dto.instance_type === ClubInstanceType.PATHFINDERS
          ? dto.instance_id
          : null,
      club_mg_id:
        dto.instance_type === ClubInstanceType.MASTER_GUILDS
          ? dto.instance_id
          : null,
    };

    return this.prisma.club_role_assignments.create({
      data: assignment,
      include: {
        users: { select: { name: true, paternal_last_name: true } },
        roles: { select: { role_name: true } },
      },
    });
  }

  async updateRoleAssignment(assignmentId: string, dto: UpdateRoleAssignmentDto) {
    return this.prisma.club_role_assignments.update({
      where: { assignment_id: assignmentId },
      data: {
        ...dto,
        modified_at: new Date(),
      },
    });
  }

  async removeRoleAssignment(assignmentId: string) {
    return this.prisma.club_role_assignments.update({
      where: { assignment_id: assignmentId },
      data: {
        active: false,
        status: 'ended',
        end_date: new Date(),
        modified_at: new Date(),
      },
    });
  }

  // ========================================
  // HELPERS
  // ========================================

  private getClubTypeName(type: ClubInstanceType): string {
    switch (type) {
      case ClubInstanceType.ADVENTURERS:
        return 'Aventureros';
      case ClubInstanceType.PATHFINDERS:
        return 'Conquistadores';
      case ClubInstanceType.MASTER_GUILDS:
        return 'Guías Mayores';
      default:
        return '';
    }
  }

  private getInstanceWhereClause(instanceId: number, type: ClubInstanceType) {
    switch (type) {
      case ClubInstanceType.ADVENTURERS:
        return { club_adv_id: instanceId };
      case ClubInstanceType.PATHFINDERS:
        return { club_pathf_id: instanceId };
      case ClubInstanceType.MASTER_GUILDS:
        return { club_mg_id: instanceId };
      default:
        throw new BadRequestException(`Invalid instance type: ${type}`);
    }
  }
}
