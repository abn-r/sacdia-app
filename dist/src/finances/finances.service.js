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
exports.FinancesService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
const pagination_dto_1 = require("../common/dto/pagination.dto");
let FinancesService = class FinancesService {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async getCategories(type) {
        return this.prisma.finances_categories.findMany({
            where: {
                active: true,
                ...(type !== undefined && { type }),
            },
            select: {
                finance_category_id: true,
                name: true,
                description: true,
                icon: true,
                type: true,
            },
            orderBy: [{ type: 'asc' }, { name: 'asc' }],
        });
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
            ...(filters?.year && { year: filters.year }),
            ...(filters?.month && { month: filters.month }),
            ...(filters?.clubTypeId && { club_type_id: filters.clubTypeId }),
            ...(filters?.categoryId && { finance_category_id: filters.categoryId }),
        };
        const [data, total] = await Promise.all([
            this.prisma.finances.findMany({
                where,
                include: {
                    finances_categories: { select: { name: true, type: true } },
                    club_types: { select: { name: true } },
                    users: { select: { name: true, paternal_last_name: true } },
                },
                orderBy: [{ finance_date: 'desc' }, { created_at: 'desc' }],
                skip: pagination?.skip ?? 0,
                take: pagination?.take ?? 20,
            }),
            this.prisma.finances.count({ where }),
        ]);
        return (0, pagination_dto_1.createPaginatedResult)(data, total, pagination ?? new pagination_dto_1.PaginationDto());
    }
    async getSummary(clubId, year, month) {
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
            active: true,
            OR: [
                { club_adv_id: { in: advIds.length > 0 ? advIds : [-1] } },
                { club_pathf_id: { in: pathfIds.length > 0 ? pathfIds : [-1] } },
                { club_mg_id: { in: mgIds.length > 0 ? mgIds : [-1] } },
            ],
            ...(year && { year }),
            ...(month && { month }),
        };
        const movements = await this.prisma.finances.findMany({
            where,
            include: {
                finances_categories: { select: { type: true } },
            },
        });
        let totalIncome = 0;
        let totalExpense = 0;
        movements.forEach((mov) => {
            if (mov.finances_categories.type === 0) {
                totalIncome += mov.amount;
            }
            else {
                totalExpense += mov.amount;
            }
        });
        return {
            club_id: clubId,
            period: year ? `${year}${month ? `-${String(month).padStart(2, '0')}` : ''}` : 'all',
            total_income: totalIncome,
            total_expense: totalExpense,
            balance: totalIncome - totalExpense,
            movement_count: movements.length,
        };
    }
    async findOne(financeId) {
        const finance = await this.prisma.finances.findUnique({
            where: { finance_id: financeId },
            include: {
                finances_categories: true,
                club_types: { select: { name: true } },
                users: { select: { name: true, paternal_last_name: true } },
            },
        });
        if (!finance) {
            throw new common_1.NotFoundException(`Finance record with ID ${financeId} not found`);
        }
        return finance;
    }
    async create(dto, createdBy) {
        return this.prisma.finances.create({
            data: {
                year: dto.year,
                month: dto.month,
                amount: dto.amount,
                description: dto.description,
                club_type_id: dto.club_type_id,
                finance_category_id: dto.finance_category_id,
                finance_date: new Date(dto.finance_date),
                club_adv_id: dto.club_adv_id,
                club_pathf_id: dto.club_pathf_id,
                club_mg_id: dto.club_mg_id,
                created_by: createdBy,
                active: true,
                created_at: new Date(),
                modified_at: new Date(),
            },
            include: {
                finances_categories: { select: { name: true, type: true } },
            },
        });
    }
    async update(financeId, dto) {
        await this.findOne(financeId);
        const updateData = {
            modified_at: new Date(),
        };
        if (dto.amount !== undefined)
            updateData.amount = dto.amount;
        if (dto.description !== undefined)
            updateData.description = dto.description;
        if (dto.finance_category_id !== undefined)
            updateData.finance_category_id = dto.finance_category_id;
        if (dto.finance_date !== undefined)
            updateData.finance_date = new Date(dto.finance_date);
        return this.prisma.finances.update({
            where: { finance_id: financeId },
            data: updateData,
            include: {
                finances_categories: { select: { name: true, type: true } },
            },
        });
    }
    async remove(financeId) {
        await this.findOne(financeId);
        return this.prisma.finances.update({
            where: { finance_id: financeId },
            data: {
                active: false,
                modified_at: new Date(),
            },
        });
    }
};
exports.FinancesService = FinancesService;
exports.FinancesService = FinancesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], FinancesService);
//# sourceMappingURL=finances.service.js.map