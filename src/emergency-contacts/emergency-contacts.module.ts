import { Module } from '@nestjs/common';
import { EmergencyContactsService } from './emergency-contacts.service';
import { EmergencyContactsController } from './emergency-contacts.controller';

@Module({
  providers: [EmergencyContactsService],
  controllers: [EmergencyContactsController]
})
export class EmergencyContactsModule {}
