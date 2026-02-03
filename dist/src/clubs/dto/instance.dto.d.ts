export declare enum ClubInstanceType {
    ADVENTURERS = "adventurers",
    PATHFINDERS = "pathfinders",
    MASTER_GUILDS = "master_guilds"
}
export declare class CreateInstanceDto {
    type: ClubInstanceType;
    souls_target?: number;
    fee?: number;
    meeting_day?: Record<string, unknown>[];
    meeting_time?: Record<string, unknown>[];
}
export declare class UpdateInstanceDto {
    souls_target?: number;
    fee?: number;
    meeting_day?: Record<string, unknown>[];
    meeting_time?: Record<string, unknown>[];
    active?: boolean;
}
