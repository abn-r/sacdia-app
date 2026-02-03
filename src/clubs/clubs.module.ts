import { Module } from '@nestjs/common';
import { ClubsController, ClubRolesController } from './clubs.controller';
import { ClubsService } from './clubs.service';
import { PrismaModule } from '../prisma/prisma.module';
import { ClubRolesGuard } from '../common/guards';

@Module({
  imports: [PrismaModule],
  controllers: [ClubsController, ClubRolesController],
  providers: [ClubsService, ClubRolesGuard],
  exports: [ClubsService],
})
export class ClubsModule {}

