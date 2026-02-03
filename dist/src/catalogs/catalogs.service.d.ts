import { PrismaService } from '../prisma/prisma.service';
export declare class CatalogsService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    getClubTypes(): Promise<{
        name: string;
        club_type_id: number;
    }[]>;
    getCountries(): Promise<{
        name: string;
        country_id: number;
        abbreviation: string;
    }[]>;
    getUnions(countryId?: number): Promise<{
        name: string;
        country_id: number;
        union_id: number;
    }[]>;
    getLocalFields(unionId?: number): Promise<{
        name: string;
        union_id: number;
        local_field_id: number;
    }[]>;
    getDistricts(localFieldId?: number): Promise<{
        name: string;
        local_field_id: number;
        districlub_type_id: number;
    }[]>;
    getChurches(districtId?: number): Promise<{
        name: string;
        districlub_type_id: number;
        church_id: number;
    }[]>;
    getRoles(category?: string): Promise<{
        role_id: string;
        role_name: string;
        role_category: import("@prisma/client").$Enums.role_category;
    }[]>;
    getEcclesiasticalYears(): Promise<{
        active: boolean;
        year_id: number;
        start_date: Date;
        end_date: Date;
    }[]>;
    getCurrentEcclesiasticalYear(): Promise<{
        active: boolean;
        year_id: number;
        start_date: Date;
        end_date: Date;
    } | null>;
    getClubIdeals(clubTypeId?: number): Promise<{
        name: string;
        club_type_id: number;
        club_ideal_id: number;
        ideal_order: number;
        ideal: string | null;
    }[]>;
}
