import { blood_type } from '@prisma/client';
export declare class UpdateUserDto {
    gender?: 'M' | 'F';
    birthday?: string;
    baptism?: boolean;
    baptism_date?: string;
    blood?: blood_type;
}
