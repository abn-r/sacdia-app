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
exports.CatalogsService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
let CatalogsService = class CatalogsService {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async getClubTypes() {
        return this.prisma.club_types.findMany({
            where: { active: true },
            select: {
                club_type_id: true,
                name: true,
            },
            orderBy: { name: 'asc' },
        });
    }
    async getCountries() {
        return this.prisma.countries.findMany({
            where: { active: true },
            select: {
                country_id: true,
                name: true,
                abbreviation: true,
            },
            orderBy: { name: 'asc' },
        });
    }
    async getUnions(countryId) {
        return this.prisma.unions.findMany({
            where: {
                active: true,
                ...(countryId && { country_id: countryId }),
            },
            select: {
                union_id: true,
                name: true,
                country_id: true,
            },
            orderBy: { name: 'asc' },
        });
    }
    async getLocalFields(unionId) {
        return this.prisma.local_fields.findMany({
            where: {
                active: true,
                ...(unionId && { union_id: unionId }),
            },
            select: {
                local_field_id: true,
                name: true,
                union_id: true,
            },
            orderBy: { name: 'asc' },
        });
    }
    async getDistricts(localFieldId) {
        return this.prisma.districts.findMany({
            where: {
                active: true,
                ...(localFieldId && { local_field_id: localFieldId }),
            },
            select: {
                districlub_type_id: true,
                name: true,
                local_field_id: true,
            },
            orderBy: { name: 'asc' },
        });
    }
    async getChurches(districtId) {
        return this.prisma.churches.findMany({
            where: {
                active: true,
                ...(districtId && { districlub_type_id: districtId }),
            },
            select: {
                church_id: true,
                name: true,
                districlub_type_id: true,
            },
            orderBy: { name: 'asc' },
        });
    }
    async getRoles(category) {
        const whereClause = {
            active: true,
        };
        if (category && (category === 'GLOBAL' || category === 'CLUB')) {
            whereClause.role_category = category;
        }
        return this.prisma.roles.findMany({
            where: whereClause,
            select: {
                role_id: true,
                role_name: true,
                role_category: true,
            },
            orderBy: { role_name: 'asc' },
        });
    }
    async getEcclesiasticalYears() {
        return this.prisma.ecclesiastical_years.findMany({
            select: {
                year_id: true,
                start_date: true,
                end_date: true,
                active: true,
            },
            orderBy: { start_date: 'desc' },
        });
    }
    async getCurrentEcclesiasticalYear() {
        const today = new Date();
        return this.prisma.ecclesiastical_years.findFirst({
            where: {
                start_date: { lte: today },
                end_date: { gte: today },
            },
            select: {
                year_id: true,
                start_date: true,
                end_date: true,
                active: true,
            },
        });
    }
    async getClubIdeals(clubTypeId) {
        return this.prisma.club_ideals.findMany({
            where: {
                active: true,
                ...(clubTypeId && { club_type_id: clubTypeId }),
            },
            select: {
                club_ideal_id: true,
                name: true,
                ideal: true,
                ideal_order: true,
                club_type_id: true,
            },
            orderBy: [{ club_type_id: 'asc' }, { ideal_order: 'asc' }],
        });
    }
};
exports.CatalogsService = CatalogsService;
exports.CatalogsService = CatalogsService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], CatalogsService);
//# sourceMappingURL=catalogs.service.js.map