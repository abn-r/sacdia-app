import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import { CreateActivityDto, UpdateActivityDto, RecordAttendanceDto, ActivityFiltersDto } from './dto';
import { PaginationDto, PaginatedResult } from '../common/dto/pagination.dto';
export declare class ActivitiesService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    findByClub(clubId: number, filters?: ActivityFiltersDto, pagination?: PaginationDto): Promise<PaginatedResult<any>>;
    findOne(activityId: number): Promise<{
        club_types: {
            name: string;
        };
        users: {
            name: string | null;
            paternal_last_name: string | null;
            user_image: string | null;
        };
        club_adv_i: {
            club_adv_id: number;
            main_club_id: number | null;
        };
        club_mg: {
            club_mg_id: number;
            main_club_id: number | null;
        };
        club_pathf: {
            club_pathf_id: number;
            main_club_id: number | null;
        };
    } & {
        classes: Prisma.JsonValue | null;
        created_at: Date | null;
        description: string | null;
        name: string;
        active: boolean;
        modified_at: Date | null;
        club_adv_id: number;
        club_pathf_id: number;
        club_mg_id: number;
        club_type_id: number;
        lat: number;
        long: number;
        activity_time: string;
        activity_place: string;
        image: string;
        platform: number;
        activity_type: number;
        link_meet: string | null;
        additional_data: string | null;
        activity_id: number;
        attendees: Prisma.JsonValue | null;
        created_by: string;
    }>;
    create(dto: CreateActivityDto, createdBy: string): Promise<{
        club_types: {
            name: string;
        };
    } & {
        classes: Prisma.JsonValue | null;
        created_at: Date | null;
        description: string | null;
        name: string;
        active: boolean;
        modified_at: Date | null;
        club_adv_id: number;
        club_pathf_id: number;
        club_mg_id: number;
        club_type_id: number;
        lat: number;
        long: number;
        activity_time: string;
        activity_place: string;
        image: string;
        platform: number;
        activity_type: number;
        link_meet: string | null;
        additional_data: string | null;
        activity_id: number;
        attendees: Prisma.JsonValue | null;
        created_by: string;
    }>;
    update(activityId: number, dto: UpdateActivityDto): Promise<{
        club_types: {
            name: string;
        };
    } & {
        classes: Prisma.JsonValue | null;
        created_at: Date | null;
        description: string | null;
        name: string;
        active: boolean;
        modified_at: Date | null;
        club_adv_id: number;
        club_pathf_id: number;
        club_mg_id: number;
        club_type_id: number;
        lat: number;
        long: number;
        activity_time: string;
        activity_place: string;
        image: string;
        platform: number;
        activity_type: number;
        link_meet: string | null;
        additional_data: string | null;
        activity_id: number;
        attendees: Prisma.JsonValue | null;
        created_by: string;
    }>;
    remove(activityId: number): Promise<{
        classes: Prisma.JsonValue | null;
        created_at: Date | null;
        description: string | null;
        name: string;
        active: boolean;
        modified_at: Date | null;
        club_adv_id: number;
        club_pathf_id: number;
        club_mg_id: number;
        club_type_id: number;
        lat: number;
        long: number;
        activity_time: string;
        activity_place: string;
        image: string;
        platform: number;
        activity_type: number;
        link_meet: string | null;
        additional_data: string | null;
        activity_id: number;
        attendees: Prisma.JsonValue | null;
        created_by: string;
    }>;
    recordAttendance(activityId: number, dto: RecordAttendanceDto): Promise<{
        classes: Prisma.JsonValue | null;
        created_at: Date | null;
        description: string | null;
        name: string;
        active: boolean;
        modified_at: Date | null;
        club_adv_id: number;
        club_pathf_id: number;
        club_mg_id: number;
        club_type_id: number;
        lat: number;
        long: number;
        activity_time: string;
        activity_place: string;
        image: string;
        platform: number;
        activity_type: number;
        link_meet: string | null;
        additional_data: string | null;
        activity_id: number;
        attendees: Prisma.JsonValue | null;
        created_by: string;
    }>;
    getAttendance(activityId: number): Promise<{
        activity_id: number;
        attendees: never[];
        activity_name?: undefined;
        total_attendees?: undefined;
    } | {
        activity_id: number;
        activity_name: string;
        total_attendees: number;
        attendees: {
            name: string | null;
            paternal_last_name: string | null;
            maternal_last_name: string | null;
            user_id: string;
            user_image: string | null;
        }[];
    }>;
}
