import { HonorsService } from './honors.service';
import { StartHonorDto, UpdateUserHonorDto } from './dto';
export declare class HonorsController {
    private readonly honorsService;
    constructor(honorsService: HonorsService);
    findAll(categoryId?: number, clubTypeId?: number, skillLevel?: number, page?: number, limit?: number): Promise<import("../common/dto/pagination.dto").PaginatedResult<any>>;
    getCategories(): Promise<{
        description: string | null;
        name: string;
        honor_category_id: number;
        icon: number;
    }[]>;
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
}
export declare class UserHonorsController {
    private readonly honorsService;
    constructor(honorsService: HonorsService);
    getUserHonors(userId: string, validated?: string): Promise<({
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
        images: import("@prisma/client/runtime/client").JsonValue;
        document: string | null;
        honor_id: number;
        user_honor_id: number;
    })[]>;
    getStats(userId: string): Promise<{
        total: number;
        validated: number;
        in_progress: number;
    }>;
    startHonor(userId: string, honorId: number, dto: StartHonorDto): Promise<{
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
        images: import("@prisma/client/runtime/client").JsonValue;
        document: string | null;
        honor_id: number;
        user_honor_id: number;
    }>;
    updateHonor(userId: string, honorId: number, dto: UpdateUserHonorDto): Promise<{
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
        images: import("@prisma/client/runtime/client").JsonValue;
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
        images: import("@prisma/client/runtime/client").JsonValue;
        document: string | null;
        honor_id: number;
        user_honor_id: number;
    }>;
}
