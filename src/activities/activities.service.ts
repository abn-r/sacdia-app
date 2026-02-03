import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import {
  CreateActivityDto,
  UpdateActivityDto,
  RecordAttendanceDto,
  ActivityFiltersDto,
} from './dto';
import {
  PaginationDto,
  PaginatedResult,
  createPaginatedResult,
} from '../common/dto/pagination.dto';

@Injectable()
export class ActivitiesService {
  constructor(private readonly prisma: PrismaService) {}

  // ========================================
  // ACTIVIDADES
  // ========================================

  async findByClub(
    clubId: number,
    filters?: ActivityFiltersDto,
    pagination?: PaginationDto,
  ): Promise<PaginatedResult<any>> {
    // Obtener las instancias del club
    const club = await this.prisma.clubs.findUnique({
      where: { club_id: clubId },
      select: {
        club_adventurers: { select: { club_adv_id: true } },
        club_pathfinders: { select: { club_pathf_id: true } },
        club_master_guild: { select: { club_mg_id: true } },
      },
    });

    if (!club) {
      throw new NotFoundException(`Club with ID ${clubId} not found`);
    }

    const advIds = club.club_adventurers.map((a) => a.club_adv_id);
    const pathfIds = club.club_pathfinders.map((p) => p.club_pathf_id);
    const mgIds = club.club_master_guild.map((m) => m.club_mg_id);

    const where = {
      OR: [
        { club_adv_id: { in: advIds.length > 0 ? advIds : [-1] } },
        { club_pathf_id: { in: pathfIds.length > 0 ? pathfIds : [-1] } },
        { club_mg_id: { in: mgIds.length > 0 ? mgIds : [-1] } },
      ],
      ...(filters?.clubTypeId && { club_type_id: filters.clubTypeId }),
      ...(filters?.active !== undefined && { active: filters.active }),
      ...(filters?.activityType !== undefined && { activity_type: filters.activityType }),
    };

    const [data, total] = await Promise.all([
      this.prisma.activities.findMany({
        where,
        include: {
          club_types: { select: { name: true } },
          users: { select: { name: true, paternal_last_name: true } },
        },
        orderBy: { created_at: 'desc' },
        skip: pagination?.skip ?? 0,
        take: pagination?.take ?? 20,
      }),
      this.prisma.activities.count({ where }),
    ]);

    return createPaginatedResult(
      data,
      total,
      pagination ?? new PaginationDto(),
    );
  }

  async findOne(activityId: number) {
    const activity = await this.prisma.activities.findUnique({
      where: { activity_id: activityId },
      include: {
        club_types: { select: { name: true } },
        users: { select: { name: true, paternal_last_name: true, user_image: true } },
        club_adv_i: { select: { club_adv_id: true, main_club_id: true } },
        club_pathf: { select: { club_pathf_id: true, main_club_id: true } },
        club_mg: { select: { club_mg_id: true, main_club_id: true } },
      },
    });

    if (!activity) {
      throw new NotFoundException(`Activity with ID ${activityId} not found`);
    }

    return activity;
  }

  async create(dto: CreateActivityDto, createdBy: string) {
    return this.prisma.activities.create({
      data: {
        name: dto.name,
        description: dto.description,
        club_type_id: dto.club_type_id,
        lat: dto.lat,
        long: dto.long,
        activity_time: dto.activity_time || '09:00',
        activity_place: dto.activity_place,
        image: dto.image,
        platform: dto.platform || 0,
        activity_type: dto.activity_type || 0,
        link_meet: dto.link_meet,
        additional_data: dto.additional_data,
        classes: dto.classes ? (dto.classes as Prisma.InputJsonValue) : Prisma.JsonNull,
        created_by: createdBy,
        club_adv_id: dto.club_adv_id,
        club_pathf_id: dto.club_pathf_id,
        club_mg_id: dto.club_mg_id,
        active: true,
        created_at: new Date(),
        modified_at: new Date(),
      },
      include: {
        club_types: { select: { name: true } },
      },
    });
  }

  async update(activityId: number, dto: UpdateActivityDto) {
    await this.findOne(activityId);

    const updateData: any = {
      modified_at: new Date(),
    };

    if (dto.name !== undefined) updateData.name = dto.name;
    if (dto.description !== undefined) updateData.description = dto.description;
    if (dto.lat !== undefined) updateData.lat = dto.lat;
    if (dto.long !== undefined) updateData.long = dto.long;
    if (dto.activity_time !== undefined) updateData.activity_time = dto.activity_time;
    if (dto.activity_place !== undefined) updateData.activity_place = dto.activity_place;
    if (dto.image !== undefined) updateData.image = dto.image;
    if (dto.platform !== undefined) updateData.platform = dto.platform;
    if (dto.activity_type !== undefined) updateData.activity_type = dto.activity_type;
    if (dto.link_meet !== undefined) updateData.link_meet = dto.link_meet;
    if (dto.active !== undefined) updateData.active = dto.active;
    if (dto.classes !== undefined) updateData.classes = dto.classes as Prisma.InputJsonValue;

    return this.prisma.activities.update({
      where: { activity_id: activityId },
      data: updateData,
      include: {
        club_types: { select: { name: true } },
      },
    });
  }

  async remove(activityId: number) {
    await this.findOne(activityId);

    return this.prisma.activities.update({
      where: { activity_id: activityId },
      data: {
        active: false,
        modified_at: new Date(),
      },
    });
  }

  // ========================================
  // ASISTENCIA
  // ========================================

  async recordAttendance(activityId: number, dto: RecordAttendanceDto) {
    const activity = await this.findOne(activityId);

    // Almacenar los asistentes en el campo JSON
    const attendees = dto.user_ids;

    return this.prisma.activities.update({
      where: { activity_id: activityId },
      data: {
        attendees: attendees as Prisma.InputJsonValue,
        modified_at: new Date(),
      },
    });
  }

  async getAttendance(activityId: number) {
    const activity = await this.findOne(activityId);

    const attendeeIds = (activity.attendees as string[]) || [];

    if (attendeeIds.length === 0) {
      return { activity_id: activityId, attendees: [] };
    }

    const attendees = await this.prisma.users.findMany({
      where: {
        user_id: { in: attendeeIds },
      },
      select: {
        user_id: true,
        name: true,
        paternal_last_name: true,
        maternal_last_name: true,
        user_image: true,
      },
    });

    return {
      activity_id: activityId,
      activity_name: activity.name,
      total_attendees: attendees.length,
      attendees,
    };
  }
}
