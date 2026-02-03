import { PrismaService } from '../prisma/prisma.service';
import { CreateEmergencyContactDto } from './dto/create-emergency-contact.dto';
import { UpdateEmergencyContactDto } from './dto/update-emergency-contact.dto';
export declare class EmergencyContactsService {
    private prisma;
    private readonly logger;
    private readonly MAX_CONTACTS;
    constructor(prisma: PrismaService);
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
    findOne(contactId: number, userId: string): Promise<{
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
    update(contactId: number, userId: string, updateDto: UpdateEmergencyContactDto): Promise<{
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
    remove(contactId: number, userId: string): Promise<{
        status: string;
        message: string;
    }>;
}
