import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  UseGuards,
  Req,
  ParseUUIDPipe,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiParam,
} from '@nestjs/swagger';
import type { Request } from 'express';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { SessionManagementService } from '../common/services/session-management.service';
import { TokenBlacklistService } from '../common/services/token-blacklist.service';

@ApiTags('auth')
@Controller('auth/sessions')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class SessionsController {
  constructor(
    private readonly sessionService: SessionManagementService,
    private readonly tokenBlacklistService: TokenBlacklistService,
  ) {}

  @Get()
  @ApiOperation({
    summary: 'Listar sesiones activas',
    description: 'Obtiene todas las sesiones activas del usuario actual',
  })
  @ApiResponse({
    status: 200,
    description: 'Lista de sesiones',
    schema: {
      properties: {
        activeSessions: { type: 'number' },
        maxSessions: { type: 'number' },
        sessions: {
          type: 'array',
          items: {
            properties: {
              sessionId: { type: 'string' },
              deviceInfo: { type: 'string' },
              ipAddress: { type: 'string' },
              createdAt: { type: 'string' },
              lastActivity: { type: 'string' },
            },
          },
        },
      },
    },
  })
  async listSessions(@Req() req: Request) {
    const userId = (req.user as any)?.user_id;
    return this.sessionService.getSessionStats(userId);
  }

  @Delete(':sessionId')
  @ApiOperation({
    summary: 'Cerrar una sesión específica',
    description: 'Cierra una sesión en otro dispositivo',
  })
  @ApiParam({ name: 'sessionId', description: 'ID de la sesión a cerrar' })
  @ApiResponse({ status: 200, description: 'Sesión cerrada' })
  async closeSession(
    @Req() req: Request,
    @Param('sessionId') sessionId: string,
  ) {
    const userId = (req.user as any)?.user_id;
    await this.sessionService.removeSession(userId, sessionId);
    return { success: true, message: 'Session closed' };
  }

  @Delete()
  @ApiOperation({
    summary: 'Cerrar todas las sesiones',
    description: 'Cierra todas las sesiones excepto la actual (logout de todos los dispositivos)',
  })
  @ApiResponse({ status: 200, description: 'Todas las sesiones cerradas' })
  async closeAllSessions(@Req() req: Request) {
    const userId = (req.user as any)?.user_id;
    
    // Blacklist todos los tokens del usuario
    await this.tokenBlacklistService.blacklistAllUserTokens(userId);
    
    // Eliminar todas las sesiones
    const count = await this.sessionService.removeAllSessions(userId);
    
    return {
      success: true,
      message: `${count} sessions closed. Please login again.`,
    };
  }
}
