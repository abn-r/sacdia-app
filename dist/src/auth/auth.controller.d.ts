import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { ResetPasswordRequestDto } from './dto/reset-password-request.dto';
export declare class AuthController {
    private readonly authService;
    constructor(authService: AuthService);
    register(registerDto: RegisterDto): Promise<{
        success: boolean;
        userId: string;
        message: string;
    }>;
    login(loginDto: LoginDto): Promise<{
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
    logout(authorization: string): Promise<{
        success: boolean;
        message: string;
    }>;
    requestPasswordReset(dto: ResetPasswordRequestDto): Promise<{
        success: boolean;
        message: string;
    }>;
    getProfile(user: {
        userId: string;
    }): Promise<{
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
    getCompletionStatus(user: {
        userId: string;
    }): Promise<{
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
