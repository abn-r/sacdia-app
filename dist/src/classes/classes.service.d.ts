import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import { PaginationDto, PaginatedResult } from '../common/dto/pagination.dto';
export declare class ClassesService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    findAll(clubTypeId?: number, pagination?: PaginationDto): Promise<PaginatedResult<any>>;
    findOne(classId: number): Promise<{
        class_modules: ({
            class_sections: {
                created_at: Date;
                description: string | null;
                name: string;
                active: boolean;
                modified_at: Date;
                section_id: number;
                module_id: number;
            }[];
        } & {
            created_at: Date;
            description: string | null;
            name: string;
            active: boolean;
            modified_at: Date;
            class_id: number;
            module_id: number;
        })[];
        club_types: {
            name: string;
        };
    } & {
        created_at: Date;
        description: string | null;
        name: string;
        active: boolean;
        modified_at: Date;
        class_id: number;
        club_type_id: number;
        minimum_age: number;
        requires_invested_gm: boolean;
        material_url: string | null;
    }>;
    getModules(classId: number): Promise<({
        class_sections: {
            created_at: Date;
            description: string | null;
            name: string;
            active: boolean;
            modified_at: Date;
            section_id: number;
            module_id: number;
        }[];
    } & {
        created_at: Date;
        description: string | null;
        name: string;
        active: boolean;
        modified_at: Date;
        class_id: number;
        module_id: number;
    })[]>;
    enrollUser(userId: string, classId: number, ecclesiasticalYearId: number): Promise<{
        created_at: Date;
        user_id: string;
        active: boolean;
        modified_at: Date;
        class_id: number;
        ecclesiastical_year_id: number;
        enrollment_id: number;
        enrollment_date: Date;
        investiture_status: import("@prisma/client").$Enums.investiture_status_enum;
        submitted_for_validation: boolean;
        submitted_at: Date | null;
        validated_by: string | null;
        validated_at: Date | null;
        rejection_reason: string | null;
        investiture_date: Date | null;
        advanced_status: boolean | null;
        locked_for_validation: boolean;
        cross_type_enrollment: boolean;
    }>;
    getUserEnrollments(userId: string, ecclesiasticalYearId?: number): Promise<({
        classes: {
            club_types: {
                name: string;
            };
            description: string | null;
            name: string;
            class_id: number;
        };
        ecclesiastical_year: {
            start_date: Date;
            end_date: Date;
        };
    } & {
        created_at: Date;
        user_id: string;
        active: boolean;
        modified_at: Date;
        class_id: number;
        ecclesiastical_year_id: number;
        enrollment_id: number;
        enrollment_date: Date;
        investiture_status: import("@prisma/client").$Enums.investiture_status_enum;
        submitted_for_validation: boolean;
        submitted_at: Date | null;
        validated_by: string | null;
        validated_at: Date | null;
        rejection_reason: string | null;
        investiture_date: Date | null;
        advanced_status: boolean | null;
        locked_for_validation: boolean;
        cross_type_enrollment: boolean;
    })[]>;
    getUserProgress(userId: string, classId: number): Promise<{
        class_id: number;
        class_name: string;
        total_sections: number;
        completed_sections: number;
        overall_progress: number;
        modules: {
            module_id: number;
            module_name: string;
            total_sections: number;
            completed_sections: number;
            progress_percentage: number;
            sections: {
                section_id: number;
                section_name: string;
                completed: boolean;
                score: number;
                evidences: string | number | true | Prisma.JsonObject | Prisma.JsonArray | null;
            }[];
        }[];
    }>;
    updateSectionProgress(userId: string, classId: number, moduleId: number, sectionId: number, score: number, evidences?: Record<string, unknown>): Promise<{
        created_at: Date;
        user_id: string;
        active: boolean;
        modified_at: Date;
        class_id: number;
        section_id: number;
        module_id: number;
        section_progress_id: number;
        score: number;
        evidences: Prisma.JsonValue | null;
    }>;
}
