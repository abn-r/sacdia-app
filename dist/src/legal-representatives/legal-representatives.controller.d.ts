import { LegalRepresentativesService } from './legal-representatives.service';
import { CreateLegalRepresentativeDto } from './dto/create-legal-representative.dto';
import { UpdateLegalRepresentativeDto } from './dto/update-legal-representative.dto';
export declare class LegalRepresentativesController {
    private readonly legalRepresentativesService;
    constructor(legalRepresentativesService: LegalRepresentativesService);
    create(userId: string, createDto: CreateLegalRepresentativeDto): Promise<{
        status: string;
        data: {
            relationship_types: {
                name: string;
            } | null;
        } & {
            id: string;
            phone: string | null;
            created_at: Date;
            name: string | null;
            paternal_last_name: string | null;
            maternal_last_name: string | null;
            user_id: string;
            modified_at: Date;
            representative_user_id: string | null;
            relationship_type_id: string | null;
        };
        message: string;
    }>;
    findOne(userId: string): Promise<{
        status: string;
        data: {
            relationship_types: {
                name: string;
                relationship_type_id: string;
            } | null;
            representative_user: {
                name: string | null;
                paternal_last_name: string | null;
                maternal_last_name: string | null;
                email: string;
                user_id: string;
            } | null;
        } & {
            id: string;
            phone: string | null;
            created_at: Date;
            name: string | null;
            paternal_last_name: string | null;
            maternal_last_name: string | null;
            user_id: string;
            modified_at: Date;
            representative_user_id: string | null;
            relationship_type_id: string | null;
        };
    }>;
    update(userId: string, updateDto: UpdateLegalRepresentativeDto): Promise<{
        status: string;
        data: {
            relationship_types: {
                name: string;
            } | null;
        } & {
            id: string;
            phone: string | null;
            created_at: Date;
            name: string | null;
            paternal_last_name: string | null;
            maternal_last_name: string | null;
            user_id: string;
            modified_at: Date;
            representative_user_id: string | null;
            relationship_type_id: string | null;
        };
        message: string;
    }>;
    remove(userId: string): Promise<{
        status: string;
        message: string;
    }>;
}
