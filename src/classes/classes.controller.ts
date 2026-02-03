import {
  Controller,
  Get,
  Post,
  Patch,
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
import { ClassesService } from './classes.service';
import { EnrollClassDto, UpdateProgressDto } from './dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PaginationDto } from '../common/dto/pagination.dto';

@ApiTags('classes')
@Controller('classes')
export class ClassesController {
  constructor(private readonly classesService: ClassesService) {}

  // ========================================
  // CLASSES - Public browsing
  // ========================================

  @Get()
  @ApiOperation({
    summary: 'Listar clases',
    description: 'Lista todas las clases activas con paginación, opcionalmente filtradas por tipo de club',
  })
  @ApiQuery({
    name: 'clubTypeId',
    required: false,
    type: Number,
    description: 'Filtrar por tipo de club (1=Aventureros, 2=Conquistadores, 3=GM)',
  })
  @ApiQuery({ name: 'page', required: false, type: Number, description: 'Número de página (1-indexed)' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Elementos por página (max 100)' })
  @ApiResponse({ status: 200, description: 'Lista paginada de clases' })
  async findAll(
    @Query('clubTypeId', new ParseIntPipe({ optional: true }))
    clubTypeId?: number,
    @Query('page', new ParseIntPipe({ optional: true })) page?: number,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    const pagination = new PaginationDto();
    if (page) pagination.page = page;
    if (limit) pagination.limit = Math.min(limit, 100);

    return this.classesService.findAll(clubTypeId, pagination);
  }

  @Get(':classId')
  @ApiOperation({
    summary: 'Obtener clase por ID',
    description: 'Retorna la clase con todos sus módulos y secciones',
  })
  @ApiParam({ name: 'classId', type: Number })
  @ApiResponse({ status: 200, description: 'Clase encontrada' })
  @ApiResponse({ status: 404, description: 'Clase no encontrada' })
  async findOne(@Param('classId', ParseIntPipe) classId: number) {
    return this.classesService.findOne(classId);
  }

  @Get(':classId/modules')
  @ApiOperation({
    summary: 'Obtener módulos de una clase',
    description: 'Lista los módulos con sus secciones',
  })
  @ApiParam({ name: 'classId', type: Number })
  @ApiResponse({ status: 200, description: 'Módulos de la clase' })
  async getModules(@Param('classId', ParseIntPipe) classId: number) {
    return this.classesService.getModules(classId);
  }
}

// ========================================
// USER ENROLLMENTS CONTROLLER
// ========================================

@ApiTags('user-classes')
@Controller('users/:userId/classes')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class UserClassesController {
  constructor(private readonly classesService: ClassesService) {}

  @Get()
  @ApiOperation({
    summary: 'Obtener inscripciones del usuario',
    description: 'Lista las clases en las que está inscrito el usuario',
  })
  @ApiParam({ name: 'userId', type: String })
  @ApiQuery({
    name: 'yearId',
    required: false,
    type: Number,
    description: 'Filtrar por año eclesiástico',
  })
  @ApiResponse({ status: 200, description: 'Inscripciones del usuario' })
  async getEnrollments(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Query('yearId', new ParseIntPipe({ optional: true })) yearId?: number,
  ) {
    return this.classesService.getUserEnrollments(userId, yearId);
  }

  @Post('enroll')
  @ApiOperation({
    summary: 'Inscribir usuario en clase',
    description: 'Inscribe al usuario en una clase para el año eclesiástico',
  })
  @ApiParam({ name: 'userId', type: String })
  @ApiResponse({ status: 201, description: 'Inscripción creada' })
  async enroll(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body() dto: EnrollClassDto,
  ) {
    return this.classesService.enrollUser(
      userId,
      dto.class_id,
      dto.ecclesiastical_year_id,
    );
  }

  @Get(':classId/progress')
  @ApiOperation({
    summary: 'Obtener progreso del usuario en una clase',
    description: 'Retorna el progreso detallado por módulo y sección',
  })
  @ApiParam({ name: 'userId', type: String })
  @ApiParam({ name: 'classId', type: Number })
  @ApiResponse({ status: 200, description: 'Progreso del usuario' })
  async getProgress(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Param('classId', ParseIntPipe) classId: number,
  ) {
    return this.classesService.getUserProgress(userId, classId);
  }

  @Patch(':classId/progress')
  @ApiOperation({
    summary: 'Actualizar progreso de sección',
    description: 'Actualiza el puntaje y evidencias de una sección específica',
  })
  @ApiParam({ name: 'userId', type: String })
  @ApiParam({ name: 'classId', type: Number })
  @ApiResponse({ status: 200, description: 'Progreso actualizado' })
  async updateProgress(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Param('classId', ParseIntPipe) classId: number,
    @Body() dto: UpdateProgressDto,
  ) {
    return this.classesService.updateSectionProgress(
      userId,
      classId,
      dto.module_id,
      dto.section_id,
      dto.score,
      dto.evidences,
    );
  }
}
