import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { LegalRepresentativesService } from './legal-representatives.service';
import { CreateLegalRepresentativeDto } from './dto/create-legal-representative.dto';
import { UpdateLegalRepresentativeDto } from './dto/update-legal-representative.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';

@ApiTags('legal-representatives')
@Controller('users/:userId/legal-representative')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class LegalRepresentativesController {
  constructor(
    private readonly legalRepresentativesService: LegalRepresentativesService,
  ) {}

  @Post()
  @ApiOperation({
    summary: 'Registrar representante legal (solo para menores de 18)',
  })
  @ApiResponse({ status: 201, description: 'Representante registrado' })
  @ApiResponse({
    status: 400,
    description: 'Usuario mayor de edad o ya tiene representante',
  })
  async create(
    @Param('userId') userId: string,
    @Body() createDto: CreateLegalRepresentativeDto,
  ) {
    return this.legalRepresentativesService.create(userId, createDto);
  }

  @Get()
  @ApiOperation({ summary: 'Obtener representante legal del usuario' })
  @ApiResponse({ status: 200, description: 'Representante encontrado' })
  @ApiResponse({ status: 404, description: 'Representante no encontrado' })
  async findOne(@Param('userId') userId: string) {
    return this.legalRepresentativesService.findOne(userId);
  }

  @Patch()
  @ApiOperation({ summary: 'Actualizar representante legal' })
  @ApiResponse({ status: 200, description: 'Representante actualizado' })
  @ApiResponse({ status: 404, description: 'Representante no encontrado' })
  async update(
    @Param('userId') userId: string,
    @Body() updateDto: UpdateLegalRepresentativeDto,
  ) {
    return this.legalRepresentativesService.update(userId, updateDto);
  }

  @Delete()
  @ApiOperation({ summary: 'Eliminar representante legal' })
  @ApiResponse({ status: 200, description: 'Representante eliminado' })
  @ApiResponse({ status: 404, description: 'Representante no encontrado' })
  async remove(@Param('userId') userId: string) {
    return this.legalRepresentativesService.remove(userId);
  }
}
