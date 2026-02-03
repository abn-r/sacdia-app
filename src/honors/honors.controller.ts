import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Query,
  Body,
  ParseIntPipe,
  ParseUUIDPipe,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiParam,
  ApiQuery,
} from '@nestjs/swagger';
import { HonorsService } from './honors.service';
import { StartHonorDto, UpdateUserHonorDto } from './dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PaginationDto } from '../common/dto/pagination.dto';

// ========================================
// CATÁLOGO DE HONORES (Público)
// ========================================

@ApiTags('honors')
@Controller('honors')
export class HonorsController {
  constructor(private readonly honorsService: HonorsService) {}

  @Get()
  @ApiOperation({
    summary: 'Listar honores',
    description: 'Lista todos los honores activos con paginación y filtros',
  })
  @ApiQuery({ name: 'categoryId', required: false, type: Number })
  @ApiQuery({ name: 'clubTypeId', required: false, type: Number })
  @ApiQuery({ name: 'skillLevel', required: false, type: Number, description: '1=Básico, 2=Avanzado, 3=Máster' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista paginada de honores' })
  async findAll(
    @Query('categoryId', new ParseIntPipe({ optional: true })) categoryId?: number,
    @Query('clubTypeId', new ParseIntPipe({ optional: true })) clubTypeId?: number,
    @Query('skillLevel', new ParseIntPipe({ optional: true })) skillLevel?: number,
    @Query('page', new ParseIntPipe({ optional: true })) page?: number,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    const pagination = new PaginationDto();
    if (page) pagination.page = page;
    if (limit) pagination.limit = Math.min(limit, 100);

    return this.honorsService.findAll(
      { categoryId, clubTypeId, skillLevel },
      pagination,
    );
  }

  @Get('categories')
  @ApiOperation({ summary: 'Listar categorías de honores' })
  @ApiResponse({ status: 200, description: 'Lista de categorías' })
  async getCategories() {
    return this.honorsService.getCategories();
  }

  @Get(':honorId')
  @ApiOperation({ summary: 'Obtener honor por ID' })
  @ApiParam({ name: 'honorId', type: Number })
  @ApiResponse({ status: 200, description: 'Honor encontrado' })
  @ApiResponse({ status: 404, description: 'Honor no encontrado' })
  async findOne(@Param('honorId', ParseIntPipe) honorId: number) {
    return this.honorsService.findOne(honorId);
  }
}

// ========================================
// HONORES DE USUARIO (Autenticado)
// ========================================

@ApiTags('user-honors')
@Controller('users/:userId/honors')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class UserHonorsController {
  constructor(private readonly honorsService: HonorsService) {}

  @Get()
  @ApiOperation({
    summary: 'Obtener honores del usuario',
    description: 'Lista los honores en los que el usuario está inscrito o ha completado',
  })
  @ApiParam({ name: 'userId', type: String })
  @ApiQuery({ name: 'validated', required: false, type: Boolean })
  @ApiResponse({ status: 200, description: 'Honores del usuario' })
  async getUserHonors(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Query('validated') validated?: string,
  ) {
    const validatedBool = validated === 'true' ? true : validated === 'false' ? false : undefined;
    return this.honorsService.getUserHonors(userId, validatedBool);
  }

  @Get('stats')
  @ApiOperation({ summary: 'Obtener estadísticas de honores del usuario' })
  @ApiParam({ name: 'userId', type: String })
  @ApiResponse({ status: 200, description: 'Estadísticas de honores' })
  async getStats(@Param('userId', ParseUUIDPipe) userId: string) {
    return this.honorsService.getUserHonorStats(userId);
  }

  @Post(':honorId')
  @ApiOperation({
    summary: 'Iniciar un honor',
    description: 'Inscribe al usuario en un honor para comenzar a trabajarlo',
  })
  @ApiParam({ name: 'userId', type: String })
  @ApiParam({ name: 'honorId', type: Number })
  @ApiResponse({ status: 201, description: 'Honor iniciado' })
  @ApiResponse({ status: 409, description: 'Usuario ya tiene este honor' })
  async startHonor(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Param('honorId', ParseIntPipe) honorId: number,
    @Body() dto: StartHonorDto,
  ) {
    return this.honorsService.startHonor(userId, honorId, dto);
  }

  @Patch(':honorId')
  @ApiOperation({
    summary: 'Actualizar progreso de honor',
    description: 'Actualiza evidencias, validación o certificado del honor',
  })
  @ApiParam({ name: 'userId', type: String })
  @ApiParam({ name: 'honorId', type: Number })
  @ApiResponse({ status: 200, description: 'Honor actualizado' })
  async updateHonor(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Param('honorId', ParseIntPipe) honorId: number,
    @Body() dto: UpdateUserHonorDto,
  ) {
    return this.honorsService.updateUserHonor(userId, honorId, dto);
  }

  @Delete(':honorId')
  @ApiOperation({
    summary: 'Abandonar honor',
    description: 'Desactiva el honor del usuario (no lo elimina)',
  })
  @ApiParam({ name: 'userId', type: String })
  @ApiParam({ name: 'honorId', type: Number })
  @ApiResponse({ status: 200, description: 'Honor abandonado' })
  async abandonHonor(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Param('honorId', ParseIntPipe) honorId: number,
  ) {
    return this.honorsService.abandonHonor(userId, honorId);
  }
}
