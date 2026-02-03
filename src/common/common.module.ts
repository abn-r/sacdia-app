import { Module, Global } from '@nestjs/common';
import { CacheModule } from '@nestjs/cache-manager';
import { TokenBlacklistService } from './services/token-blacklist.service';
import { SessionManagementService } from './services/session-management.service';
import { MfaService } from './services/mfa.service';
import { IpWhitelistGuard } from './guards/ip-whitelist.guard';

@Global()
@Module({
  imports: [
    // ==========================================
    // CACHE - Para Token Blacklist y Sessions
    // ==========================================
    CacheModule.register({
      ttl: 86400000, // 24 horas en ms
      max: 10000, // Máximo 10k items en memoria
      isGlobal: true,
    }),
  ],
  providers: [
    // ==========================================
    // SERVICIOS DE SEGURIDAD
    // ==========================================
    TokenBlacklistService,
    SessionManagementService,
    MfaService,
    IpWhitelistGuard,
  ],
  exports: [
    CacheModule,
    TokenBlacklistService,
    SessionManagementService,
    MfaService,
    IpWhitelistGuard,
  ],
})
export class CommonModule {}
