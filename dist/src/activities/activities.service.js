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
exports.ActivitiesService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
const client_1 = require("@prisma/client");
const pagination_dto_1 = require("../common/dto/pagination.dto");
let ActivitiesService = class ActivitiesService {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async findByClub(clubId, filters, pagination) {
        const club = await this.prisma.clubs.findUnique({
            where: { club_id: clubId },
            select: {
                club_adventurers: { select: { club_adv_id: true } },
                club_pathfinders: { select: { club_pathf_id: true } },
                club_master_guild: { select: { club_mg_id: true } },
            },
        });
        if (!club) {
            throw new common_1.NotFoundException(`Club with ID ${clubId} not found`);
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
        return (0, pagination_dto_1.createPaginatedResult)(data, total, pagination ?? new pagination_dto_1.PaginationDto());
    }
    async findOne(activityId) {
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
            throw new common_1.NotFoundException(`Activity with ID ${activityId} not found`);
        }
        return activity;
    }
    async create(dto, createdBy) {
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
                classes: dto.classes ? dto.classes : client_1.Prisma.JsonNull,
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
    async update(activityId, dto) {
        await this.findOne(activityId);
        const updateData = {
            modified_at: new Date(),
        };
        if (dto.name !== undefined)
            updateData.name = dto.name;
        if (dto.description !== undefined)
            updateData.description = dto.description;
        if (dto.lat !== undefined)
            updateData.lat = dto.lat;
        if (dto.long !== undefined)
            updateData.long = dto.long;
        if (dto.activity_time !== undefined)
            updateData.activity_time = dto.activity_time;
        if (dto.activity_place !== undefined)
            updateData.activity_place = dto.activity_place;
        if (dto.image !== undefined)
            updateData.image = dto.image;
        if (dto.platform !== undefined)
            updateData.platform = dto.platform;
        if (dto.activity_type !== undefined)
            updateData.activity_type = dto.activity_type;
        if (dto.link_meet !== undefined)
            updateData.link_meet = dto.link_meet;
        if (dto.active !== undefined)
            updateData.active = dto.active;
        if (dto.classes !== undefined)
            updateData.classes = dto.classes;
        return this.prisma.activities.update({
            where: { activity_id: activityId },
            data: updateData,
            include: {
                club_types: { select: { name: true } },
            },
        });
    }
    async remove(activityId) {
        await this.findOne(activityId);
        return this.prisma.activities.update({
            where: { activity_id: activityId },
            data: {
                active: false,
                modified_at: new Date(),
            },
        });
    }
    async recordAttendance(activityId, dto) {
        const activity = await this.findOne(activityId);
        const attendees = dto.user_ids;
        return this.prisma.activities.update({
            where: { activity_id: activityId },
            data: {
                attendees: attendees,
                modified_at: new Date(),
            },
        });
    }
    async getAttendance(activityId) {
        const activity = await this.findOne(activityId);
        const attendeeIds = activity.attendees || [];
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
};
exports.ActivitiesService = ActivitiesService;
exports.ActivitiesService = ActivitiesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], ActivitiesService);
//# sourceMappingURL=activities.service.js.map