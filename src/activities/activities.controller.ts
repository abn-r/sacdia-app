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
  UseGuards,
  Request,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiParam,
  ApiQuery,
} from '@nestjs/swagger';
import { ActivitiesService } from './activities.service';
import { CreateActivityDto, UpdateActivityDto, RecordAttendanceDto } from './dto';
import { JwtAuthGuard, ClubRolesGuard } from '../common/guards';
import { ClubRoles } from '../common/decorators';
import { PaginationDto } from '../common/dto/pagination.dto';

@ApiTags('activities')
@Controller()
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class ActivitiesController {
  constructor(private readonly activitiesService: ActivitiesService) {}

  // ========================================
  // ACTIVIDADES POR CLUB
  // ========================================

  @Get('clubs/:clubId/activities')
  @ApiOperation({
    summary: 'Listar actividades del club',
    description: 'Obtiene todas las actividades de las instancias del club',
  })
  @ApiParam({ name: 'clubId', type: Number })
  @ApiQuery({ name: 'clubTypeId', required: false, type: Number })
  @ApiQuery({ name: 'active', required: false, type: Boolean })
  @ApiQuery({ name: 'activityType', required: false, type: Number })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista paginada de actividades' })
  async findByClub(
    @Param('clubId', ParseIntPipe) clubId: number,
    @Query('clubTypeId', new ParseIntPipe({ optional: true })) clubTypeId?: number,
    @Query('active') active?: string,
    @Query('activityType', new ParseIntPipe({ optional: true })) activityType?: number,
    @Query('page', new ParseIntPipe({ optional: true })) page?: number,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    const pagination = new PaginationDto();
    if (page) pagination.page = page;
    if (limit) pagination.limit = Math.min(limit, 100);

    return this.activitiesService.findByClub(
      clubId,
      {
        clubTypeId,
        active: active === 'true' ? true : active === 'false' ? false : undefined,
        activityType,
      },
      pagination,
    );
  }

  @Post('clubs/:clubId/activities')
  @UseGuards(ClubRolesGuard)
  @ClubRoles('director', 'subdirector', 'secretary', 'counselor')
  @ApiOperation({
    summary: 'Crear actividad',
    description: 'Crea una nueva actividad para el club (requiere rol de liderazgo)',
  })
  @ApiParam({ name: 'clubId', type: Number })
  @ApiResponse({ status: 201, description: 'Actividad creada' })
  @ApiResponse({ status: 403, description: 'Permisos insuficientes' })
  async create(
    @Param('clubId', ParseIntPipe) clubId: number,
    @Body() dto: CreateActivityDto,
    @Request() req: any,
  ) {
    return this.activitiesService.create(dto, req.user.sub);
  }

  // ========================================
  // ACTIVIDAD INDIVIDUAL
  // ========================================

  @Get('activities/:activityId')
  @ApiOperation({ summary: 'Obtener actividad por ID' })
  @ApiParam({ name: 'activityId', type: Number })
  @ApiResponse({ status: 200, description: 'Actividad encontrada' })
  @ApiResponse({ status: 404, description: 'Actividad no encontrada' })
  async findOne(@Param('activityId', ParseIntPipe) activityId: number) {
    return this.activitiesService.findOne(activityId);
  }

  @Patch('activities/:activityId')
  @ApiOperation({ summary: 'Actualizar actividad' })
  @ApiParam({ name: 'activityId', type: Number })
  @ApiResponse({ status: 200, description: 'Actividad actualizada' })
  async update(
    @Param('activityId', ParseIntPipe) activityId: number,
    @Body() dto: UpdateActivityDto,
  ) {
    return this.activitiesService.update(activityId, dto);
  }

  @Delete('activities/:activityId')
  @ApiOperation({ summary: 'Desactivar actividad' })
  @ApiParam({ name: 'activityId', type: Number })
  @ApiResponse({ status: 200, description: 'Actividad desactivada' })
  async remove(@Param('activityId', ParseIntPipe) activityId: number) {
    return this.activitiesService.remove(activityId);
  }

  // ========================================
  // ASISTENCIA
  // ========================================

  @Post('activities/:activityId/attendance')
  @ApiOperation({
    summary: 'Registrar asistencia',
    description: 'Registra la lista de usuarios que asistieron a la actividad',
  })
  @ApiParam({ name: 'activityId', type: Number })
  @ApiResponse({ status: 201, description: 'Asistencia registrada' })
  async recordAttendance(
    @Param('activityId', ParseIntPipe) activityId: number,
    @Body() dto: RecordAttendanceDto,
  ) {
    return this.activitiesService.recordAttendance(activityId, dto);
  }

  @Get('activities/:activityId/attendance')
  @ApiOperation({
    summary: 'Obtener asistencia',
    description: 'Obtiene la lista de usuarios que asistieron a la actividad',
  })
  @ApiParam({ name: 'activityId', type: Number })
  @ApiResponse({ status: 200, description: 'Lista de asistentes' })
  async getAttendance(@Param('activityId', ParseIntPipe) activityId: number) {
    return this.activitiesService.getAttendance(activityId);
  }
}
