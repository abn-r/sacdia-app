import { Module } from '@nestjs/common';
import { LegalRepresentativesController } from './legal-representatives.controller';
import { LegalRepresentativesService } from './legal-representatives.service';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [UsersModule], // Para usar UsersService
  controllers: [LegalRepresentativesController],
  providers: [LegalRepresentativesService],
  exports: [LegalRepresentativesService],
})
export class LegalRepresentativesModule {}
