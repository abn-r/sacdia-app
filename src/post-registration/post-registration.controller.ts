import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { PostRegistrationService } from './post-registration.service';
import { CompleteClubSelectionDto } from './dto/complete-club-selection.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';

@ApiTags('post-registration')
@Controller('users/:userId/post-registration')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class PostRegistrationController {
  constructor(
    private readonly postRegistrationService: PostRegistrationService,
  ) {}

  @Get('status')
  @ApiOperation({ summary: 'Obtener estado del post-registro' })
  @ApiResponse({ status: 200, description: 'Estado actual' })
  async getStatus(@Param('userId') userId: string) {
    return this.postRegistrationService.getStatus(userId);
  }

  @Post('step-1/complete')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Completar Paso 1: Foto de perfil',
    description: 'Valida que el usuario tenga foto subida',
  })
  @ApiResponse({ status: 200, description: 'Paso 1 completado' })
  @ApiResponse({
    status: 400,
    description: 'Usuario no tiene foto de perfil',
  })
  async completeStep1(@Param('userId') userId: string) {
    return this.postRegistrationService.completeStep1(userId);
  }

  @Post('step-2/complete')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Completar Paso 2: Información personal',
    description:
      'Valida: género, cumpleaños, bautismo, >= 1 contacto emergencia, representante legal si < 18',
  })
  @ApiResponse({ status: 200, description: 'Paso 2 completado' })
  @ApiResponse({
    status: 400,
    description: 'Faltan datos requeridos',
  })
  async completeStep2(@Param('userId') userId: string) {
    return this.postRegistrationService.completeStep2(userId);
  }

  @Post('step-3/complete')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Completar Paso 3: Selección de club',
    description:
      'Transacción completa: actualiza país/unión/campo, asigna rol member, inscribe en clase, marca post-registro completo',
  })
  @ApiResponse({
    status: 200,
    description: 'Paso 3 completado - POST-REGISTRO COMPLETO',
  })
  @ApiResponse({
    status: 400,
    description: 'Club no encontrado o datos inválidos',
  })
  async completeStep3(
    @Param('userId') userId: string,
    @Body() dto: CompleteClubSelectionDto,
  ) {
    return this.postRegistrationService.completeStep3(userId, dto);
  }
}
