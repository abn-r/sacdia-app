export declare class PaginationDto {
    page?: number;
    limit?: number;
    get skip(): number;
    get take(): number;
}
export interface PaginatedResult<T> {
    data: T[];
    meta: {
        page: number;
        limit: number;
        total: number;
        totalPages: number;
        hasNextPage: boolean;
        hasPreviousPage: boolean;
    };
}
export declare function createPaginatedResult<T>(data: T[], total: number, pagination: PaginationDto): PaginatedResult<T>;
