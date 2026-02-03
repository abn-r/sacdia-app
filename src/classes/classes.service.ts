import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import {
  PaginationDto,
  PaginatedResult,
  createPaginatedResult,
} from '../common/dto/pagination.dto';

@Injectable()
export class ClassesService {
  constructor(private readonly prisma: PrismaService) {}

  // ========================================
  // CLASSES
  // ========================================

  async findAll(
    clubTypeId?: number,
    pagination?: PaginationDto,
  ): Promise<PaginatedResult<any>> {
    const where = {
      active: true,
      ...(clubTypeId && { club_type_id: clubTypeId }),
    };

    const [data, total] = await Promise.all([
      this.prisma.classes.findMany({
        where,
        include: {
          club_types: { select: { name: true } },
          _count: { select: { class_modules: true } },
        },
        orderBy: [{ club_type_id: 'asc' }, { minimum_age: 'asc' }],
        skip: pagination?.skip ?? 0,
        take: pagination?.take ?? 50,
      }),
      this.prisma.classes.count({ where }),
    ]);

    return createPaginatedResult(
      data,
      total,
      pagination ?? new PaginationDto(),
    );
  }

  async findOne(classId: number) {
    const classData = await this.prisma.classes.findUnique({
      where: { class_id: classId },
      include: {
        club_types: { select: { name: true } },
        class_modules: {
          where: { active: true },
          include: {
            class_sections: {
              where: { active: true },
              orderBy: { section_id: 'asc' },
            },
          },
          orderBy: { module_id: 'asc' },
        },
      },
    });

    if (!classData) {
      throw new NotFoundException(`Class with ID ${classId} not found`);
    }

    return classData;
  }

  async getModules(classId: number) {
    const classData = await this.findOne(classId);
    return classData.class_modules;
  }

  // ========================================
  // ENROLLMENTS
  // ========================================

  async enrollUser(userId: string, classId: number, ecclesiasticalYearId: number) {
    // Check if already enrolled
    const existing = await this.prisma.enrollments.findFirst({
      where: {
        user_id: userId,
        class_id: classId,
        ecclesiastical_year_id: ecclesiasticalYearId,
      },
    });

    if (existing) {
      return existing;
    }

    return this.prisma.enrollments.create({
      data: {
        user_id: userId,
        class_id: classId,
        ecclesiastical_year_id: ecclesiasticalYearId,
        enrollment_date: new Date(),
      },
      include: {
        classes: { select: { name: true } },
        ecclesiastical_year: { select: { start_date: true, end_date: true } },
      },
    });
  }

  async getUserEnrollments(userId: string, ecclesiasticalYearId?: number) {
    return this.prisma.enrollments.findMany({
      where: {
        user_id: userId,
        ...(ecclesiasticalYearId && { ecclesiastical_year_id: ecclesiasticalYearId }),
      },
      include: {
        classes: {
          select: {
            class_id: true,
            name: true,
            description: true,
            club_types: { select: { name: true } },
          },
        },
        ecclesiastical_year: { select: { start_date: true, end_date: true } },
      },
      orderBy: { enrollment_date: 'desc' },
    });
  }

  // ========================================
  // PROGRESS
  // ========================================

  async getUserProgress(userId: string, classId: number) {
    // Get all sections for this class
    const classData = await this.findOne(classId);

    // Get user's section progress
    const sectionProgress = await this.prisma.class_section_progress.findMany({
      where: {
        user_id: userId,
        class_id: classId,
        active: true,
      },
    });

    // Calculate completion
    let totalSections = 0;
    let completedSections = 0;

    const modulesProgress = classData.class_modules.map((module) => {
      const sectionsInModule = module.class_sections.length;
      totalSections += sectionsInModule;

      const completedInModule = sectionProgress.filter(
        (sp) =>
          sp.module_id === module.module_id && sp.score >= 70,
      ).length;
      completedSections += completedInModule;

      return {
        module_id: module.module_id,
        module_name: module.name,
        total_sections: sectionsInModule,
        completed_sections: completedInModule,
        progress_percentage:
          sectionsInModule > 0
            ? Math.round((completedInModule / sectionsInModule) * 100)
            : 0,
        sections: module.class_sections.map((section) => {
          const progress = sectionProgress.find(
            (sp) => sp.section_id === section.section_id,
          );
          return {
            section_id: section.section_id,
            section_name: section.name,
            completed: progress ? progress.score >= 70 : false,
            score: progress?.score || 0,
            evidences: progress?.evidences || null,
          };
        }),
      };
    });

    return {
      class_id: classId,
      class_name: classData.name,
      total_sections: totalSections,
      completed_sections: completedSections,
      overall_progress:
        totalSections > 0
          ? Math.round((completedSections / totalSections) * 100)
          : 0,
      modules: modulesProgress,
    };
  }

  async updateSectionProgress(
    userId: string,
    classId: number,
    moduleId: number,
    sectionId: number,
    score: number,
    evidences?: Record<string, unknown>,
  ) {
    // Upsert the section progress
    const existing = await this.prisma.class_section_progress.findFirst({
      where: {
        user_id: userId,
        class_id: classId,
        module_id: moduleId,
        section_id: sectionId,
      },
    });

    if (existing) {
      return this.prisma.class_section_progress.update({
        where: { section_progress_id: existing.section_progress_id },
        data: {
          score,
          evidences: evidences ? (evidences as Prisma.InputJsonValue) : undefined,
          modified_at: new Date(),
        },
      });
    }

    return this.prisma.class_section_progress.create({
      data: {
        user_id: userId,
        class_id: classId,
        module_id: moduleId,
        section_id: sectionId,
        score,
        evidences: evidences ? (evidences as Prisma.InputJsonValue) : Prisma.JsonNull,
        active: true,
      },
    });
  }
}
