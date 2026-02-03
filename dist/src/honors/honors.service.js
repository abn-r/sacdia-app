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
exports.HonorsService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
const pagination_dto_1 = require("../common/dto/pagination.dto");
let HonorsService = class HonorsService {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async findAll(filters, pagination) {
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
        return (0, pagination_dto_1.createPaginatedResult)(data, total, pagination ?? new pagination_dto_1.PaginationDto());
    }
    async findOne(honorId) {
        const honor = await this.prisma.honors.findUnique({
            where: { honor_id: honorId },
            include: {
                honors_categories: true,
                club_types: { select: { name: true } },
                master_honors: { select: { name: true } },
            },
        });
        if (!honor) {
            throw new common_1.NotFoundException(`Honor with ID ${honorId} not found`);
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
    async getUserHonors(userId, validated) {
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
    async startHonor(userId, honorId, dto) {
        await this.findOne(honorId);
        const existing = await this.prisma.users_honors.findFirst({
            where: {
                user_id: userId,
                honor_id: honorId,
                active: true,
            },
        });
        if (existing) {
            throw new common_1.ConflictException('User already has this honor in progress');
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
    async updateUserHonor(userId, honorId, dto) {
        const userHonor = await this.prisma.users_honors.findFirst({
            where: {
                user_id: userId,
                honor_id: honorId,
                active: true,
            },
        });
        if (!userHonor) {
            throw new common_1.NotFoundException('User honor not found');
        }
        const updateData = {
            modified_at: new Date(),
        };
        if (dto.validate !== undefined)
            updateData.validate = dto.validate;
        if (dto.certificate)
            updateData.certificate = dto.certificate;
        if (dto.images)
            updateData.images = dto.images;
        if (dto.document)
            updateData.document = dto.document;
        if (dto.date)
            updateData.date = new Date(dto.date);
        return this.prisma.users_honors.update({
            where: { user_honor_id: userHonor.user_honor_id },
            data: updateData,
            include: {
                honors: { select: { name: true, honor_image: true } },
            },
        });
    }
    async abandonHonor(userId, honorId) {
        const userHonor = await this.prisma.users_honors.findFirst({
            where: {
                user_id: userId,
                honor_id: honorId,
                active: true,
            },
        });
        if (!userHonor) {
            throw new common_1.NotFoundException('User honor not found');
        }
        return this.prisma.users_honors.update({
            where: { user_honor_id: userHonor.user_honor_id },
            data: {
                active: false,
                modified_at: new Date(),
            },
        });
    }
    async getUserHonorStats(userId) {
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
};
exports.HonorsService = HonorsService;
exports.HonorsService = HonorsService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], HonorsService);
//# sourceMappingURL=honors.service.js.map