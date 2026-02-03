"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ClassesService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
const client_1 = require("@prisma/client");
const pagination_dto_1 = require("../common/dto/pagination.dto");
let ClassesService = class ClassesService {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async findAll(clubTypeId, pagination) {
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
        return (0, pagination_dto_1.createPaginatedResult)(data, total, pagination ?? new pagination_dto_1.PaginationDto());
    }
    async findOne(classId) {
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
            throw new common_1.NotFoundException(`Class with ID ${classId} not found`);
        }
        return classData;
    }
    async getModules(classId) {
        const classData = await this.findOne(classId);
        return classData.class_modules;
    }
    async enrollUser(userId, classId, ecclesiasticalYearId) {
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
    async getUserEnrollments(userId, ecclesiasticalYearId) {
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
    async getUserProgress(userId, classId) {
        const classData = await this.findOne(classId);
        const sectionProgress = await this.prisma.class_section_progress.findMany({
            where: {
                user_id: userId,
                class_id: classId,
                active: true,
            },
        });
        let totalSections = 0;
        let completedSections = 0;
        const modulesProgress = classData.class_modules.map((module) => {
            const sectionsInModule = module.class_sections.length;
            totalSections += sectionsInModule;
            const completedInModule = sectionProgress.filter((sp) => sp.module_id === module.module_id && sp.score >= 70).length;
            completedSections += completedInModule;
            return {
                module_id: module.module_id,
                module_name: module.name,
                total_sections: sectionsInModule,
                completed_sections: completedInModule,
                progress_percentage: sectionsInModule > 0
                    ? Math.round((completedInModule / sectionsInModule) * 100)
                    : 0,
                sections: module.class_sections.map((section) => {
                    const progress = sectionProgress.find((sp) => sp.section_id === section.section_id);
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
            overall_progress: totalSections > 0
                ? Math.round((completedSections / totalSections) * 100)
                : 0,
            modules: modulesProgress,
        };
    }
    async updateSectionProgress(userId, classId, moduleId, sectionId, score, evidences) {
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
                    evidences: evidences ? evidences : undefined,
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
                evidences: evidences ? evidences : client_1.Prisma.JsonNull,
                active: true,
            },
        });
    }
};
exports.ClassesService = ClassesService;
exports.ClassesService = ClassesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], ClassesService);
//# sourceMappingURL=classes.service.js.map