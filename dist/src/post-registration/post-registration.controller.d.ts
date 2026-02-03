import { PostRegistrationService } from './post-registration.service';
import { CompleteClubSelectionDto } from './dto/complete-club-selection.dto';
export declare class PostRegistrationController {
    private readonly postRegistrationService;
    constructor(postRegistrationService: PostRegistrationService);
    getStatus(userId: string): Promise<{
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
    completeStep1(userId: string): Promise<{
        status: string;
        message: string;
    }>;
    completeStep2(userId: string): Promise<{
        status: string;
        message: string;
    }>;
    completeStep3(userId: string, dto: CompleteClubSelectionDto): Promise<{
        status: string;
        message: string;
        data: {
            clubType: "adventurers" | "pathfinders" | "master_guild";
            clubId: number;
            classId: number;
            ecclesiasticalYear: number;
        };
    }>;
}
