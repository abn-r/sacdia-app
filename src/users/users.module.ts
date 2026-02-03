import { Module } from '@nestjs/common';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { SupabaseService } from '../common/supabase.service';

@Module({
  controllers: [UsersController],
  providers: [UsersService, SupabaseService],
  exports: [UsersService], // Para usar en otros módulos
})
export class UsersModule {}
