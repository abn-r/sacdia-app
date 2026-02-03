import { SupabaseClient } from '@supabase/supabase-js';
import { ConfigService } from '@nestjs/config';
export declare class SupabaseService {
    private configService;
    private supabaseAdmin;
    constructor(configService: ConfigService);
    get admin(): SupabaseClient;
}
