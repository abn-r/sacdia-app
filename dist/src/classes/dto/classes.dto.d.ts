export declare class EnrollClassDto {
    class_id: number;
    ecclesiastical_year_id: number;
}
export declare class UpdateProgressDto {
    module_id: number;
    section_id: number;
    score: number;
    evidences?: Record<string, unknown>;
}
