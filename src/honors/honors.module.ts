import { Module } from '@nestjs/common';
import { HonorsController, UserHonorsController } from './honors.controller';
import { HonorsService } from './honors.service';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [HonorsController, UserHonorsController],
  providers: [HonorsService],
  exports: [HonorsService],
})
export class HonorsModule {}
