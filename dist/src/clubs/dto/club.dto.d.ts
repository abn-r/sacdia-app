export declare class CreateClubDto {
    name: string;
    description?: string;
    local_field_id: number;
    districlub_type_id: number;
    church_id: number;
    address?: string;
    coordinates?: {
        lat: number;
        lng: number;
    };
}
export declare class UpdateClubDto {
    name?: string;
    description?: string;
    address?: string;
    coordinates?: {
        lat: number;
        lng: number;
    };
    active?: boolean;
}
