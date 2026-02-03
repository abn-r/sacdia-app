import { PrismaService } from '../prisma/prisma.service';
import { SupabaseService } from '../common/supabase.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { ResetPasswordRequestDto } from './dto/reset-password-request.dto';
export declare class AuthService {
    private prisma;
    private supabase;
    private readonly logger;
    constructor(prisma: PrismaService, supabase: SupabaseService);
    register(dto: RegisterDto): Promise<{
        success: boolean;
        userId: string;
        message: string;
    }>;
    login(dto: LoginDto): Promise<{
        status: string;
        data: {
            accessToken: string;
            refreshToken: string;
            user: {
                id: string;
                email: string;
                name: string | null;
                paternal_last_name: string | null;
                maternal_last_name: string | null;
                avatar: string | null;
            };
            needsPostRegistration: boolean;
            postRegistrationStatus: {
                complete: boolean;
                profile_picture_complete: boolean;
                personal_info_complete: boolean;
                club_selection_complete: boolean;
            };
        };
    }>;
    logout(accessToken: string): Promise<{
        success: boolean;
        message: string;
    }>;
    requestPasswordReset(dto: ResetPasswordRequestDto): Promise<{
        success: boolean;
        message: string;
    }>;
    getProfile(userId: string): Promise<{
        status: string;
        data: {
            created_at: Date;
            name: string | null;
            paternal_last_name: string | null;
            maternal_last_name: string | null;
            email: string;
            user_id: string;
            gender: string | null;
            birthday: Date | null;
            baptism: boolean;
            baptism_date: Date | null;
            user_image: string | null;
            country_id: number | null;
            union_id: number | null;
            local_field_id: number | null;
        };
    }>;
    getCompletionStatus(userId: string): Promise<{
        status: string;
        data: {
            complete: boolean;
            steps: {
                profilePicture: boolean;
                personalInfo: boolean;
                clubSelection: boolean;
            };
            nextStep: string | null;
            dateCompleted: Date | null;
        };
    }>;
}
