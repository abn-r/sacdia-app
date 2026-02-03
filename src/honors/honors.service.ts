import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import { StartHonorDto, UpdateUserHonorDto, HonorFiltersDto } from './dto';
import {
  PaginationDto,
  PaginatedResult,
  createPaginatedResult,
} from '../common/dto/pagination.dto';

@Injectable()
export class HonorsService {
  constructor(private readonly prisma: PrismaService) {}

  // ========================================
  // CATÁLOGO DE HONORES
  // ========================================

  async findAll(
    filters?: HonorFiltersDto,
    pagination?: PaginationDto,
  ): Promise<PaginatedResult<any>> {
    const where = {
      active: true,
      ...(filters?.categoryId && { honors_category_id: filters.categoryId }),
      ...(filters?.clubTypeId && { club_type_id: filters.clubTypeId }),
      ...(filters?.skillLevel && { skill_level: filters.skillLevel }),
    };

    const [data, total] = await Promise.all([
      this.prisma.honors.findMany({
        where,
        include: {
          honors_categories: { select: { name: true, icon: true } },
          club_types: { select: { name: true } },
        },
        orderBy: [{ honors_category_id: 'asc' }, { name: 'asc' }],
        skip: pagination?.skip ?? 0,
        take: pagination?.take ?? 50,
      }),
      this.prisma.honors.count({ where }),
    ]);

    return createPaginatedResult(
      data,
      total,
      pagination ?? new PaginationDto(),
    );
  }

  async findOne(honorId: number) {
    const honor = await this.prisma.honors.findUnique({
      where: { honor_id: honorId },
      include: {
        honors_categories: true,
        club_types: { select: { name: true } },
        master_honors: { select: { name: true } },
      },
    });

    if (!honor) {
      throw new NotFoundException(`Honor with ID ${honorId} not found`);
    }

    return honor;
  }

  async getCategories() {
    return this.prisma.honors_categories.findMany({
      where: { active: true },
      select: {
        honor_category_id: true,
        name: true,
        description: true,
        icon: true,
      },
      orderBy: { name: 'asc' },
    });
  }

  // ========================================
  // HONORES DE USUARIO
  // ========================================

  async getUserHonors(userId: string, validated?: boolean) {
    return this.prisma.users_honors.findMany({
      where: {
        user_id: userId,
        active: true,
        ...(validated !== undefined && { validate: validated }),
      },
      include: {
        honors: {
          select: {
            honor_id: true,
            name: true,
            honor_image: true,
            skill_level: true,
            honors_categories: { select: { name: true, icon: true } },
          },
        },
      },
      orderBy: { created_at: 'desc' },
    });
  }

  async startHonor(userId: string, honorId: number, dto?: StartHonorDto) {
    // Verificar que el honor existe
    await this.findOne(honorId);

    // Verificar que no esté ya inscrito
    const existing = await this.prisma.users_honors.findFirst({
      where: {
        user_id: userId,
        honor_id: honorId,
        active: true,
      },
    });

    if (existing) {
      throw new ConflictException('User already has this honor in progress');
    }

    return this.prisma.users_honors.create({
      data: {
        user_id: userId,
        honor_id: honorId,
        date: dto?.date ? new Date(dto.date) : new Date(),
        validate: false,
        certificate: '',
        images: [],
        active: true,
      },
      include: {
        honors: {
          select: {
            name: true,
            honor_image: true,
            honors_categories: { select: { name: true } },
          },
        },
      },
    });
  }

  async updateUserHonor(
    userId: string,
    honorId: number,
    dto: UpdateUserHonorDto,
  ) {
    const userHonor = await this.prisma.users_honors.findFirst({
      where: {
        user_id: userId,
        honor_id: honorId,
        active: true,
      },
    });

    if (!userHonor) {
      throw new NotFoundException('User honor not found');
    }

    const updateData: any = {
      modified_at: new Date(),
    };

    if (dto.validate !== undefined) updateData.validate = dto.validate;
    if (dto.certificate) updateData.certificate = dto.certificate;
    if (dto.images) updateData.images = dto.images as Prisma.InputJsonValue;
    if (dto.document) updateData.document = dto.document;
    if (dto.date) updateData.date = new Date(dto.date);

    return this.prisma.users_honors.update({
      where: { user_honor_id: userHonor.user_honor_id },
      data: updateData,
      include: {
        honors: { select: { name: true, honor_image: true } },
      },
    });
  }

  async abandonHonor(userId: string, honorId: number) {
    const userHonor = await this.prisma.users_honors.findFirst({
      where: {
        user_id: userId,
        honor_id: honorId,
        active: true,
      },
    });

    if (!userHonor) {
      throw new NotFoundException('User honor not found');
    }

    return this.prisma.users_honors.update({
      where: { user_honor_id: userHonor.user_honor_id },
      data: {
        active: false,
        modified_at: new Date(),
      },
    });
  }

  // ========================================
  // ESTADÍSTICAS
  // ========================================

  async getUserHonorStats(userId: string) {
    const [total, validated, inProgress] = await Promise.all([
      this.prisma.users_honors.count({
        where: { user_id: userId, active: true },
      }),
      this.prisma.users_honors.count({
        where: { user_id: userId, active: true, validate: true },
      }),
      this.prisma.users_honors.count({
        where: { user_id: userId, active: true, validate: false },
      }),
    ]);

    return {
      total,
      validated,
      in_progress: inProgress,
    };
  }
}
