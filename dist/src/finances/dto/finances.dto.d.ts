export declare class CreateFinanceDto {
    year: number;
    month: number;
    amount: number;
    description?: string;
    club_type_id: number;
    finance_category_id: number;
    finance_date: string;
    club_adv_id?: number;
    club_pathf_id?: number;
    club_mg_id?: number;
}
export declare class UpdateFinanceDto {
    amount?: number;
    description?: string;
    finance_category_id?: number;
    finance_date?: string;
}
export declare class FinanceFiltersDto {
    year?: number;
    month?: number;
    clubTypeId?: number;
    categoryId?: number;
}
