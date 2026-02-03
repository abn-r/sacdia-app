import { Module } from '@nestjs/common';
import { PostRegistrationController } from './post-registration.controller';
import { PostRegistrationService } from './post-registration.service';
import { UsersModule } from '../users/users.module';
import { LegalRepresentativesModule } from '../legal-representatives/legal-representatives.module';

@Module({
  imports: [UsersModule, LegalRepresentativesModule],
  controllers: [PostRegistrationController],
  providers: [PostRegistrationService],
  exports: [PostRegistrationService],
})
export class PostRegistrationModule {}
