import { Module } from '@nestjs/common';
import { FinancesController } from './finances.controller';
import { FinancesService } from './finances.service';
import { PrismaModule } from '../prisma/prisma.module';
import { ClubRolesGuard } from '../common/guards';

@Module({
  imports: [PrismaModule],
  controllers: [FinancesController],
  providers: [FinancesService, ClubRolesGuard],
  exports: [FinancesService],
})
export class FinancesModule {}
