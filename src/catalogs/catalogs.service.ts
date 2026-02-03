import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { role_category } from '@prisma/client';

@Injectable()
export class CatalogsService {
  constructor(private readonly prisma: PrismaService) {}

  // ========================================
  // CLUB TYPES
  // ========================================
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

  // ========================================
  // COUNTRIES
  // ========================================
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

  // ========================================
  // UNIONS
  // ========================================
  async getUnions(countryId?: number) {
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

  // ========================================
  // LOCAL FIELDS (Campos Locales)
  // ========================================
  async getLocalFields(unionId?: number) {
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

  // ========================================
  // DISTRICTS
  // ========================================
  async getDistricts(localFieldId?: number) {
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

  // ========================================
  // CHURCHES
  // ========================================
  async getChurches(districtId?: number) {
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

  // ========================================
  // ROLES
  // ========================================
  async getRoles(category?: string) {
    const whereClause: { active: boolean; role_category?: role_category } = {
      active: true,
    };

    if (category && (category === 'GLOBAL' || category === 'CLUB')) {
      whereClause.role_category = category as role_category;
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

  // ========================================
  // ECCLESIASTICAL YEARS
  // ========================================
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

  // ========================================
  // CLUB IDEALS (Ley, Voto, Lema, etc.)
  // ========================================
  async getClubIdeals(clubTypeId?: number) {
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
}
