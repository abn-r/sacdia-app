import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import { CreateClubDto, UpdateClubDto, CreateInstanceDto, UpdateInstanceDto, AssignRoleDto, UpdateRoleAssignmentDto, ClubInstanceType } from './dto';
import { PaginationDto, PaginatedResult } from '../common/dto/pagination.dto';
export declare class ClubsService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    findAll(filters?: {
        localFieldId?: number;
        districtId?: number;
        churchId?: number;
        active?: boolean;
    }, pagination?: PaginationDto): Promise<PaginatedResult<any>>;
    findOne(clubId: number): Promise<{
        churches: {
            created_at: Date | null;
            name: string;
            active: boolean;
            modified_at: Date | null;
            districlub_type_id: number;
            church_id: number;
        };
        club_adventurers: {
            created_at: Date;
            active: boolean;
            modified_at: Date;
            club_adv_id: number;
            club_type_id: number;
            souls_target: number;
            fee: number;
            meeting_day: Prisma.JsonValue[];
            meeting_time: Prisma.JsonValue[];
            main_club_id: number | null;
        }[];
        club_pathfinders: {
            created_at: Date;
            active: boolean;
            modified_at: Date;
            club_pathf_id: number;
            club_type_id: number;
            souls_target: number;
            fee: number;
            meeting_day: Prisma.JsonValue[];
            meeting_time: Prisma.JsonValue[];
            main_club_id: number | null;
        }[];
        districts: {
            created_at: Date | null;
            name: string;
            active: boolean;
            modified_at: Date | null;
            local_field_id: number;
            districlub_type_id: number;
        };
        local_fields: {
            created_at: Date | null;
            name: string;
            active: boolean;
            modified_at: Date | null;
            union_id: number;
            local_field_id: number;
            abbreviation: string;
        };
        club_master_guild: {
            created_at: Date;
            active: boolean;
            modified_at: Date;
            club_mg_id: number;
            club_type_id: number;
            souls_target: number;
            fee: number;
            meeting_day: Prisma.JsonValue[];
            meeting_time: Prisma.JsonValue[];
            main_club_id: number | null;
        }[];
    } & {
        created_at: Date | null;
        description: string | null;
        name: string;
        active: boolean;
        modified_at: Date | null;
        local_field_id: number;
        districlub_type_id: number;
        church_id: number;
        address: string | null;
        coordinates: Prisma.JsonValue;
        club_id: number;
    }>;
    create(dto: CreateClubDto): Promise<{
        created_at: Date | null;
        description: string | null;
        name: string;
        active: boolean;
        modified_at: Date | null;
        local_field_id: number;
        districlub_type_id: number;
        church_id: number;
        address: string | null;
        coordinates: Prisma.JsonValue;
        club_id: number;
    }>;
    update(clubId: number, dto: UpdateClubDto): Promise<{
        created_at: Date | null;
        description: string | null;
        name: string;
        active: boolean;
        modified_at: Date | null;
        local_field_id: number;
        districlub_type_id: number;
        church_id: number;
        address: string | null;
        coordinates: Prisma.JsonValue;
        club_id: number;
    }>;
    remove(clubId: number): Promise<{
        created_at: Date | null;
        description: string | null;
        name: string;
        active: boolean;
        modified_at: Date | null;
        local_field_id: number;
        districlub_type_id: number;
        church_id: number;
        address: string | null;
        coordinates: Prisma.JsonValue;
        club_id: number;
    }>;
    getInstances(clubId: number): Promise<{
        adventurers: {
            created_at: Date;
            active: boolean;
            modified_at: Date;
            club_adv_id: number;
            club_type_id: number;
            souls_target: number;
            fee: number;
            meeting_day: Prisma.JsonValue[];
            meeting_time: Prisma.JsonValue[];
            main_club_id: number | null;
        }[];
        pathfinders: {
            created_at: Date;
            active: boolean;
            modified_at: Date;
            club_pathf_id: number;
            club_type_id: number;
            souls_target: number;
            fee: number;
            meeting_day: Prisma.JsonValue[];
            meeting_time: Prisma.JsonValue[];
            main_club_id: number | null;
        }[];
        master_guilds: {
            created_at: Date;
            active: boolean;
            modified_at: Date;
            club_mg_id: number;
            club_type_id: number;
            souls_target: number;
            fee: number;
            meeting_day: Prisma.JsonValue[];
            meeting_time: Prisma.JsonValue[];
            main_club_id: number | null;
        }[];
    }>;
    getInstance(clubId: number, type: ClubInstanceType): Promise<{
        created_at: Date;
        active: boolean;
        modified_at: Date;
        club_adv_id: number;
        club_type_id: number;
        souls_target: number;
        fee: number;
        meeting_day: Prisma.JsonValue[];
        meeting_time: Prisma.JsonValue[];
        main_club_id: number | null;
    }[] | {
        created_at: Date;
        active: boolean;
        modified_at: Date;
        club_pathf_id: number;
        club_type_id: number;
        souls_target: number;
        fee: number;
        meeting_day: Prisma.JsonValue[];
        meeting_time: Prisma.JsonValue[];
        main_club_id: number | null;
    }[] | {
        created_at: Date;
        active: boolean;
        modified_at: Date;
        club_mg_id: number;
        club_type_id: number;
        souls_target: number;
        fee: number;
        meeting_day: Prisma.JsonValue[];
        meeting_time: Prisma.JsonValue[];
        main_club_id: number | null;
    }[]>;
    createInstance(clubId: number, dto: CreateInstanceDto): Promise<{
        created_at: Date;
        active: boolean;
        modified_at: Date;
        club_adv_id: number;
        club_type_id: number;
        souls_target: number;
        fee: number;
        meeting_day: Prisma.JsonValue[];
        meeting_time: Prisma.JsonValue[];
        main_club_id: number | null;
    } | {
        created_at: Date;
        active: boolean;
        modified_at: Date;
        club_pathf_id: number;
        club_type_id: number;
        souls_target: number;
        fee: number;
        meeting_day: Prisma.JsonValue[];
        meeting_time: Prisma.JsonValue[];
        main_club_id: number | null;
    } | {
        created_at: Date;
        active: boolean;
        modified_at: Date;
        club_mg_id: number;
        club_type_id: number;
        souls_target: number;
        fee: number;
        meeting_day: Prisma.JsonValue[];
        meeting_time: Prisma.JsonValue[];
        main_club_id: number | null;
    }>;
    updateInstance(instanceId: number, type: ClubInstanceType, dto: UpdateInstanceDto): Promise<{
        created_at: Date;
        active: boolean;
        modified_at: Date;
        club_adv_id: number;
        club_type_id: number;
        souls_target: number;
        fee: number;
        meeting_day: Prisma.JsonValue[];
        meeting_time: Prisma.JsonValue[];
        main_club_id: number | null;
    } | {
        created_at: Date;
        active: boolean;
        modified_at: Date;
        club_pathf_id: number;
        club_type_id: number;
        souls_target: number;
        fee: number;
        meeting_day: Prisma.JsonValue[];
        meeting_time: Prisma.JsonValue[];
        main_club_id: number | null;
    } | {
        created_at: Date;
        active: boolean;
        modified_at: Date;
        club_mg_id: number;
        club_type_id: number;
        souls_target: number;
        fee: number;
        meeting_day: Prisma.JsonValue[];
        meeting_time: Prisma.JsonValue[];
        main_club_id: number | null;
    }>;
    getMembers(instanceId: number, type: ClubInstanceType): Promise<({
        roles: {
            role_id: string;
            role_name: string;
            role_category: import("@prisma/client").$Enums.role_category;
        };
        users: {
            name: string | null;
            paternal_last_name: string | null;
            maternal_last_name: string | null;
            user_id: string;
            user_image: string | null;
        };
    } & {
        status: string | null;
        created_at: Date;
        user_id: string;
        active: boolean;
        modified_at: Date;
        role_id: string;
        start_date: Date;
        end_date: Date | null;
        club_adv_id: number | null;
        club_pathf_id: number | null;
        club_mg_id: number | null;
        assignment_id: string;
        ecclesiastical_year_id: number;
    })[]>;
    assignRole(dto: AssignRoleDto): Promise<{
        roles: {
            role_name: string;
        };
        users: {
            name: string | null;
            paternal_last_name: string | null;
        };
    } & {
        status: string | null;
        created_at: Date;
        user_id: string;
        active: boolean;
        modified_at: Date;
        role_id: string;
        start_date: Date;
        end_date: Date | null;
        club_adv_id: number | null;
        club_pathf_id: number | null;
        club_mg_id: number | null;
        assignment_id: string;
        ecclesiastical_year_id: number;
    }>;
    updateRoleAssignment(assignmentId: string, dto: UpdateRoleAssignmentDto): Promise<{
        status: string | null;
        created_at: Date;
        user_id: string;
        active: boolean;
        modified_at: Date;
        role_id: string;
        start_date: Date;
        end_date: Date | null;
        club_adv_id: number | null;
        club_pathf_id: number | null;
        club_mg_id: number | null;
        assignment_id: string;
        ecclesiastical_year_id: number;
    }>;
    removeRoleAssignment(assignmentId: string): Promise<{
        status: string | null;
        created_at: Date;
        user_id: string;
        active: boolean;
        modified_at: Date;
        role_id: string;
        start_date: Date;
        end_date: Date | null;
        club_adv_id: number | null;
        club_pathf_id: number | null;
        club_mg_id: number | null;
        assignment_id: string;
        ecclesiastical_year_id: number;
    }>;
    private getClubTypeName;
    private getInstanceWhereClause;
}
