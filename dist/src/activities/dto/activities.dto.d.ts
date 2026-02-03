export declare class CreateActivityDto {
    name: string;
    description?: string;
    club_type_id: number;
    lat: number;
    long: number;
    activity_time?: string;
    activity_place: string;
    image: string;
    platform?: number;
    activity_type?: number;
    link_meet?: string;
    additional_data?: string;
    classes?: number[];
    club_adv_id: number;
    club_pathf_id: number;
    club_mg_id: number;
}
export declare class UpdateActivityDto {
    name?: string;
    description?: string;
    lat?: number;
    long?: number;
    activity_time?: string;
    activity_place?: string;
    image?: string;
    platform?: number;
    activity_type?: number;
    link_meet?: string;
    active?: boolean;
    classes?: number[];
}
export declare class RecordAttendanceDto {
    user_ids: string[];
}
export declare class ActivityFiltersDto {
    clubTypeId?: number;
    active?: boolean;
    activityType?: number;
}
