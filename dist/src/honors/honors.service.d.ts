import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import { StartHonorDto, UpdateUserHonorDto, HonorFiltersDto } from './dto';
import { PaginationDto, PaginatedResult } from '../common/dto/pagination.dto';
export declare class HonorsService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    findAll(filters?: HonorFiltersDto, pagination?: PaginationDto): Promise<PaginatedResult<any>>;
    findOne(honorId: number): Promise<{
        club_types: {
            name: string;
        };
        honors_categories: {
            created_at: Date | null;
            description: string | null;
            name: string;
            active: boolean;
            modified_at: Date | null;
            honor_category_id: number;
            icon: number;
        };
        master_honors: {
            name: string;
        } | null;
    } & {
        created_at: Date;
        description: string | null;
        name: string;
        active: boolean;
        modified_at: Date | null;
        year: string | null;
        club_type_id: number;
        material_url: string;
        honor_id: number;
        honor_image: string;
        honors_category_id: number;
        master_honors_id: number | null;
        approval: number;
        skill_level: number;
    }>;
    getCategories(): Promise<{
        description: string | null;
        name: string;
        honor_category_id: number;
        icon: number;
    }[]>;
    getUserHonors(userId: string, validated?: boolean): Promise<({
        honors: {
            honors_categories: {
                name: string;
                icon: number;
            };
            name: string;
            honor_id: number;
            honor_image: string;
            skill_level: number;
        };
    } & {
        created_at: Date | null;
        user_id: string;
        active: boolean;
        modified_at: Date | null;
        certificate: string;
        date: Date;
        validate: boolean;
        images: Prisma.JsonValue;
        document: string | null;
        honor_id: number;
        user_honor_id: number;
    })[]>;
    startHonor(userId: string, honorId: number, dto?: StartHonorDto): Promise<{
        honors: {
            honors_categories: {
                name: string;
            };
            name: string;
            honor_image: string;
        };
    } & {
        created_at: Date | null;
        user_id: string;
        active: boolean;
        modified_at: Date | null;
        certificate: string;
        date: Date;
        validate: boolean;
        images: Prisma.JsonValue;
        document: string | null;
        honor_id: number;
        user_honor_id: number;
    }>;
    updateUserHonor(userId: string, honorId: number, dto: UpdateUserHonorDto): Promise<{
        honors: {
            name: string;
            honor_image: string;
        };
    } & {
        created_at: Date | null;
        user_id: string;
        active: boolean;
        modified_at: Date | null;
        certificate: string;
        date: Date;
        validate: boolean;
        images: Prisma.JsonValue;
        document: string | null;
        honor_id: number;
        user_honor_id: number;
    }>;
    abandonHonor(userId: string, honorId: number): Promise<{
        created_at: Date | null;
        user_id: string;
        active: boolean;
        modified_at: Date | null;
        certificate: string;
        date: Date;
        validate: boolean;
        images: Prisma.JsonValue;
        document: string | null;
        honor_id: number;
        user_honor_id: number;
    }>;
    getUserHonorStats(userId: string): Promise<{
        total: number;
        validated: number;
        in_progress: number;
    }>;
}
