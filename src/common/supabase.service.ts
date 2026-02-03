import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class SupabaseService {
  private supabaseAdmin: SupabaseClient;

  constructor(private configService: ConfigService) {
    const supabaseUrl = this.configService.get<string>('SUPABASE_URL')!;
    const supabaseKey =
      this.configService.get<string>('SUPABASE_SERVICE_ROLE_KEY')!;

    console.log('--- SUPABASE DEBUG ---');
    console.log('URL:', supabaseUrl);
    console.log('Key Length:', supabaseKey?.length);
    console.log('Key Start:', supabaseKey?.substring(0, 10));
    console.log('----------------------');

    this.supabaseAdmin = createClient(supabaseUrl, supabaseKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });
  }

  get admin(): SupabaseClient {
    return this.supabaseAdmin;
  }
}
