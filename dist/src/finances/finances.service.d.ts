import { PrismaService } from '../prisma/prisma.service';
import { CreateFinanceDto, UpdateFinanceDto, FinanceFiltersDto } from './dto';
import { PaginationDto, PaginatedResult } from '../common/dto/pagination.dto';
export declare class FinancesService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    getCategories(type?: number): Promise<{
        type: number;
        description: string | null;
        name: string;
        icon: number | null;
        finance_category_id: number;
    }[]>;
    findByClub(clubId: number, filters?: FinanceFiltersDto, pagination?: PaginationDto): Promise<PaginatedResult<any>>;
    getSummary(clubId: number, year?: number, month?: number): Promise<{
        club_id: number;
        period: string;
        total_income: number;
        total_expense: number;
        balance: number;
        movement_count: number;
    }>;
    findOne(financeId: number): Promise<{
        club_types: {
            name: string;
        };
        finances_categories: {
            type: number;
            created_at: Date | null;
            description: string | null;
            name: string;
            active: boolean;
            modified_at: Date | null;
            icon: number | null;
            finance_category_id: number;
        };
        users: {
            name: string | null;
            paternal_last_name: string | null;
        };
    } & {
        created_at: Date | null;
        description: string | null;
        active: boolean;
        modified_at: Date | null;
        year: number;
        club_adv_id: number | null;
        club_pathf_id: number | null;
        club_mg_id: number | null;
        club_type_id: number;
        created_by: string;
        month: number;
        amount: number;
        finance_category_id: number;
        finance_date: Date;
        finance_id: number;
    }>;
    create(dto: CreateFinanceDto, createdBy: string): Promise<{
        finances_categories: {
            type: number;
            name: string;
        };
    } & {
        created_at: Date | null;
        description: string | null;
        active: boolean;
        modified_at: Date | null;
        year: number;
        club_adv_id: number | null;
        club_pathf_id: number | null;
        club_mg_id: number | null;
        club_type_id: number;
        created_by: string;
        month: number;
        amount: number;
        finance_category_id: number;
        finance_date: Date;
        finance_id: number;
    }>;
    update(financeId: number, dto: UpdateFinanceDto): Promise<{
        finances_categories: {
            type: number;
            name: string;
        };
    } & {
        created_at: Date | null;
        description: string | null;
        active: boolean;
        modified_at: Date | null;
        year: number;
        club_adv_id: number | null;
        club_pathf_id: number | null;
        club_mg_id: number | null;
        club_type_id: number;
        created_by: string;
        month: number;
        amount: number;
        finance_category_id: number;
        finance_date: Date;
        finance_id: number;
    }>;
    remove(financeId: number): Promise<{
        created_at: Date | null;
        description: string | null;
        active: boolean;
        modified_at: Date | null;
        year: number;
        club_adv_id: number | null;
        club_pathf_id: number | null;
        club_mg_id: number | null;
        club_type_id: number;
        created_by: string;
        month: number;
        amount: number;
        finance_category_id: number;
        finance_date: Date;
        finance_id: number;
    }>;
}
