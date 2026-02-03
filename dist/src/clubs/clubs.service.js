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
exports.ClubsService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
const dto_1 = require("./dto");
const pagination_dto_1 = require("../common/dto/pagination.dto");
let ClubsService = class ClubsService {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async findAll(filters, pagination) {
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
        return (0, pagination_dto_1.createPaginatedResult)(data, total, pagination ?? new pagination_dto_1.PaginationDto());
    }
    async findOne(clubId) {
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
            throw new common_1.NotFoundException(`Club with ID ${clubId} not found`);
        }
        return club;
    }
    async create(dto) {
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
    async update(clubId, dto) {
        await this.findOne(clubId);
        return this.prisma.clubs.update({
            where: { club_id: clubId },
            data: {
                ...dto,
                modified_at: new Date(),
            },
        });
    }
    async remove(clubId) {
        await this.findOne(clubId);
        return this.prisma.clubs.update({
            where: { club_id: clubId },
            data: { active: false, modified_at: new Date() },
        });
    }
    async getInstances(clubId) {
        const club = await this.findOne(clubId);
        return {
            adventurers: club.club_adventurers,
            pathfinders: club.club_pathfinders,
            master_guilds: club.club_master_guild,
        };
    }
    async getInstance(clubId, type) {
        const club = await this.findOne(clubId);
        switch (type) {
            case dto_1.ClubInstanceType.ADVENTURERS:
                return club.club_adventurers;
            case dto_1.ClubInstanceType.PATHFINDERS:
                return club.club_pathfinders;
            case dto_1.ClubInstanceType.MASTER_GUILDS:
                return club.club_master_guild;
            default:
                throw new common_1.BadRequestException(`Invalid instance type: ${type}`);
        }
    }
    async createInstance(clubId, dto) {
        await this.findOne(clubId);
        const clubType = await this.prisma.club_types.findFirst({
            where: {
                name: this.getClubTypeName(dto.type),
                active: true,
            },
        });
        if (!clubType) {
            throw new common_1.BadRequestException(`Club type for ${dto.type} not found in catalog`);
        }
        const meetingDay = (dto.meeting_day || []);
        const meetingTime = (dto.meeting_time || []);
        switch (dto.type) {
            case dto_1.ClubInstanceType.ADVENTURERS:
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
            case dto_1.ClubInstanceType.PATHFINDERS:
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
            case dto_1.ClubInstanceType.MASTER_GUILDS:
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
                throw new common_1.BadRequestException(`Invalid instance type: ${dto.type}`);
        }
    }
    async updateInstance(instanceId, type, dto) {
        const updateData = {
            modified_at: new Date(),
        };
        if (dto.souls_target !== undefined)
            updateData.souls_target = dto.souls_target;
        if (dto.fee !== undefined)
            updateData.fee = dto.fee;
        if (dto.active !== undefined)
            updateData.active = dto.active;
        if (dto.meeting_day)
            updateData.meeting_day = dto.meeting_day;
        if (dto.meeting_time)
            updateData.meeting_time = dto.meeting_time;
        switch (type) {
            case dto_1.ClubInstanceType.ADVENTURERS:
                return this.prisma.club_adventurers.update({
                    where: { club_adv_id: instanceId },
                    data: updateData,
                });
            case dto_1.ClubInstanceType.PATHFINDERS:
                return this.prisma.club_pathfinders.update({
                    where: { club_pathf_id: instanceId },
                    data: updateData,
                });
            case dto_1.ClubInstanceType.MASTER_GUILDS:
                return this.prisma.club_master_guilds.update({
                    where: { club_mg_id: instanceId },
                    data: updateData,
                });
            default:
                throw new common_1.BadRequestException(`Invalid instance type: ${type}`);
        }
    }
    async getMembers(instanceId, type) {
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
    async assignRole(dto) {
        const assignment = {
            user_id: dto.user_id,
            role_id: dto.role_id,
            ecclesiastical_year_id: dto.ecclesiastical_year_id,
            start_date: dto.start_date,
            end_date: dto.end_date,
            active: true,
            status: 'active',
            club_adv_id: dto.instance_type === dto_1.ClubInstanceType.ADVENTURERS
                ? dto.instance_id
                : null,
            club_pathf_id: dto.instance_type === dto_1.ClubInstanceType.PATHFINDERS
                ? dto.instance_id
                : null,
            club_mg_id: dto.instance_type === dto_1.ClubInstanceType.MASTER_GUILDS
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
    async updateRoleAssignment(assignmentId, dto) {
        return this.prisma.club_role_assignments.update({
            where: { assignment_id: assignmentId },
            data: {
                ...dto,
                modified_at: new Date(),
            },
        });
    }
    async removeRoleAssignment(assignmentId) {
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
    getClubTypeName(type) {
        switch (type) {
            case dto_1.ClubInstanceType.ADVENTURERS:
                return 'Aventureros';
            case dto_1.ClubInstanceType.PATHFINDERS:
                return 'Conquistadores';
            case dto_1.ClubInstanceType.MASTER_GUILDS:
                return 'Guías Mayores';
            default:
                return '';
        }
    }
    getInstanceWhereClause(instanceId, type) {
        switch (type) {
            case dto_1.ClubInstanceType.ADVENTURERS:
                return { club_adv_id: instanceId };
            case dto_1.ClubInstanceType.PATHFINDERS:
                return { club_pathf_id: instanceId };
            case dto_1.ClubInstanceType.MASTER_GUILDS:
                return { club_mg_id: instanceId };
            default:
                throw new common_1.BadRequestException(`Invalid instance type: ${type}`);
        }
    }
};
exports.ClubsService = ClubsService;
exports.ClubsService = ClubsService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], ClubsService);
//# sourceMappingURL=clubs.service.js.map