import { EmergencyContactsService } from './emergency-contacts.service';
import { CreateEmergencyContactDto } from './dto/create-emergency-contact.dto';
import { UpdateEmergencyContactDto } from './dto/update-emergency-contact.dto';
export declare class EmergencyContactsController {
    private readonly emergencyContactsService;
    constructor(emergencyContactsService: EmergencyContactsService);
    create(userId: string, createDto: CreateEmergencyContactDto): Promise<{
        status: string;
        data: {
            phone: string;
            created_at: Date;
            name: string;
            active: boolean;
            modified_at: Date;
            relationship_type: number;
            primary: boolean;
            owner_id: string;
            emergency_id: number;
            contact_user_id: string | null;
        };
        message: string;
    }>;
    findAll(userId: string): Promise<{
        status: string;
        data: {
            phone: string;
            created_at: Date;
            name: string;
            modified_at: Date;
            relationship_type: number;
            primary: boolean;
            emergency_id: number;
        }[];
        meta: {
            total: number;
            remaining: number;
        };
    }>;
    findOne(userId: string, contactId: number): Promise<{
        status: string;
        data: {
            phone: string;
            created_at: Date;
            name: string;
            active: boolean;
            modified_at: Date;
            relationship_type: number;
            primary: boolean;
            owner_id: string;
            emergency_id: number;
            contact_user_id: string | null;
        };
    }>;
    update(userId: string, contactId: number, updateDto: UpdateEmergencyContactDto): Promise<{
        status: string;
        data: {
            phone: string;
            created_at: Date;
            name: string;
            active: boolean;
            modified_at: Date;
            relationship_type: number;
            primary: boolean;
            owner_id: string;
            emergency_id: number;
            contact_user_id: string | null;
        };
        message: string;
    }>;
    remove(userId: string, contactId: number): Promise<{
        status: string;
        message: string;
    }>;
}
