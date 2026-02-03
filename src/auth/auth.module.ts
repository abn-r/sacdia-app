import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigService } from '@nestjs/config';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import { SupabaseService } from '../common/supabase.service';
import { MfaController } from './mfa.controller';
import { SessionsController } from './sessions.controller';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get<string>('SUPABASE_JWT_SECRET'),
        signOptions: {
          expiresIn: '7d',
        },
      }),
    }),
  ],
  controllers: [AuthController, MfaController, SessionsController],
  providers: [AuthService, JwtStrategy, SupabaseService],
  exports: [AuthService, JwtStrategy, PassportModule],
})
export class AuthModule {}

