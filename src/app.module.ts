import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { CommonModule } from './common/common.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { EmergencyContactsModule } from './emergency-contacts/emergency-contacts.module';
import { LegalRepresentativesModule } from './legal-representatives/legal-representatives.module';
import { PostRegistrationModule } from './post-registration/post-registration.module';
import { CatalogsModule } from './catalogs/catalogs.module';
import { ClubsModule } from './clubs/clubs.module';
import { ClassesModule } from './classes/classes.module';
import { HonorsModule } from './honors/honors.module';
import { ActivitiesModule } from './activities/activities.module';
import { FinancesModule } from './finances/finances.module';
import { HealthController } from './health/health.controller';

@Module({
  imports: [
    // ==========================================
    // CONFIGURACIÓN
    // ==========================================
    ConfigModule.forRoot({
      isGlobal: true,
    }),

    // ==========================================
    // SEGURIDAD - Rate Limiting
    // ==========================================
    ThrottlerModule.forRoot([
      {
        name: 'short',
        ttl: 1000, // 1 segundo
        limit: 3, // 3 requests por segundo
      },
      {
        name: 'medium',
        ttl: 10000, // 10 segundos
        limit: 20, // 20 requests por 10 segundos
      },
      {
        name: 'long',
        ttl: 60000, // 1 minuto
        limit: 100, // 100 requests por minuto
      },
    ]),

    // ==========================================
    // MÓDULOS DE APLICACIÓN
    // ==========================================
    PrismaModule,
    CommonModule,
    AuthModule,
    UsersModule,
    EmergencyContactsModule,
    LegalRepresentativesModule,
    PostRegistrationModule,
    CatalogsModule,
    ClubsModule,
    ClassesModule,
    HonorsModule,
    ActivitiesModule,
    FinancesModule,
  ],
  controllers: [AppController, HealthController],
  providers: [
    AppService,
    // ==========================================
    // GUARD GLOBAL - Rate Limiting
    // ==========================================
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}
