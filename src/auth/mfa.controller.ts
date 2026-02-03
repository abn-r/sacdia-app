import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  UseGuards,
  Req,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import type { Request } from 'express';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { MfaService } from '../common/services/mfa.service';
import { VerifyMfaDto, UnenrollMfaDto } from './dto/mfa.dto';

@ApiTags('auth')
@Controller('auth/mfa')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class MfaController {
  constructor(private readonly mfaService: MfaService) {}

  @Post('enroll')
  @ApiOperation({
    summary: 'Iniciar enrolamiento de 2FA',
    description: 'Genera un QR code y secret para configurar en tu app de autenticación',
  })
  @ApiResponse({
    status: 200,
    description: 'QR code y secret generados',
    schema: {
      properties: {
        factorId: { type: 'string' },
        qrCode: { type: 'string', description: 'Base64 del QR code' },
        secret: { type: 'string', description: 'Secret para configurar manualmente' },
        uri: { type: 'string', description: 'URI para apps de autenticación' },
      },
    },
  })
  async enrollMfa(@Req() req: Request) {
    const token = this.extractToken(req);
    return this.mfaService.enrollMfa(token);
  }

  @Post('verify')
  @ApiOperation({
    summary: 'Verificar y activar 2FA',
    description: 'Verifica el código TOTP y activa 2FA para la cuenta',
  })
  @ApiResponse({ status: 200, description: '2FA activado exitosamente' })
  @ApiResponse({ status: 401, description: 'Código inválido' })
  async verifyMfa(@Req() req: Request, @Body() dto: VerifyMfaDto) {
    const token = this.extractToken(req);
    return this.mfaService.verifyAndActivateMfa(token, dto.factorId, dto.code);
  }

  @Get('factors')
  @ApiOperation({
    summary: 'Listar factores MFA configurados',
    description: 'Obtiene la lista de métodos 2FA configurados para el usuario',
  })
  @ApiResponse({
    status: 200,
    description: 'Lista de factores',
    schema: {
      type: 'array',
      items: {
        properties: {
          id: { type: 'string' },
          friendlyName: { type: 'string' },
          factorType: { type: 'string' },
          status: { type: 'string' },
          createdAt: { type: 'string' },
        },
      },
    },
  })
  async listFactors(@Req() req: Request) {
    const token = this.extractToken(req);
    return this.mfaService.listFactors(token);
  }

  @Delete('unenroll')
  @ApiOperation({
    summary: 'Deshabilitar 2FA',
    description: 'Elimina un factor MFA de la cuenta',
  })
  @ApiResponse({ status: 200, description: '2FA deshabilitado' })
  async unenrollMfa(@Req() req: Request, @Body() dto: UnenrollMfaDto) {
    const token = this.extractToken(req);
    await this.mfaService.unenrollFactor(token, dto.factorId);
    return { success: true, message: '2FA disabled successfully' };
  }

  @Get('status')
  @ApiOperation({
    summary: 'Verificar estado de 2FA',
    description: 'Indica si el usuario tiene 2FA habilitado y su nivel de autenticación',
  })
  @ApiResponse({
    status: 200,
    schema: {
      properties: {
        mfaEnabled: { type: 'boolean' },
        currentLevel: { type: 'string', description: 'aal1 = password, aal2 = password + MFA' },
        factors: { type: 'array' },
      },
    },
  })
  async getMfaStatus(@Req() req: Request) {
    const token = this.extractToken(req);
    const [enabled, level, factors] = await Promise.all([
      this.mfaService.hasMfaEnabled(token),
      this.mfaService.getAuthenticatorAssuranceLevel(token),
      this.mfaService.listFactors(token),
    ]);

    return {
      mfaEnabled: enabled,
      currentLevel: level.currentLevel,
      nextLevel: level.nextLevel,
      factors,
    };
  }

  private extractToken(req: Request): string {
    const authHeader = req.headers.authorization;
    return authHeader?.replace('Bearer ', '') || '';
  }
}
