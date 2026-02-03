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
import { FinancesService } from './finances.service';
import { CreateFinanceDto, UpdateFinanceDto } from './dto';
import { JwtAuthGuard, ClubRolesGuard } from '../common/guards';
import { ClubRoles } from '../common/decorators';
import { PaginationDto } from '../common/dto/pagination.dto';

@ApiTags('finances')
@Controller()
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class FinancesController {
  constructor(private readonly financesService: FinancesService) {}

  // ========================================
  // CATEGORÍAS
  // ========================================

  @Get('finances/categories')
  @ApiOperation({
    summary: 'Listar categorías financieras',
    description: 'Lista todas las categorías de ingresos y egresos',
  })
  @ApiQuery({
    name: 'type',
    required: false,
    type: Number,
    description: '0=Ingresos, 1=Egresos',
  })
  @ApiResponse({ status: 200, description: 'Lista de categorías' })
  async getCategories(
    @Query('type', new ParseIntPipe({ optional: true })) type?: number,
  ) {
    return this.financesService.getCategories(type);
  }

  // ========================================
  // FINANZAS POR CLUB
  // ========================================

  @Get('clubs/:clubId/finances')
  @ApiOperation({
    summary: 'Listar movimientos financieros del club',
    description: 'Obtiene todos los movimientos de las instancias del club',
  })
  @ApiParam({ name: 'clubId', type: Number })
  @ApiQuery({ name: 'year', required: false, type: Number })
  @ApiQuery({ name: 'month', required: false, type: Number })
  @ApiQuery({ name: 'clubTypeId', required: false, type: Number })
  @ApiQuery({ name: 'categoryId', required: false, type: Number })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Lista paginada de movimientos' })
  async findByClub(
    @Param('clubId', ParseIntPipe) clubId: number,
    @Query('year', new ParseIntPipe({ optional: true })) year?: number,
    @Query('month', new ParseIntPipe({ optional: true })) month?: number,
    @Query('clubTypeId', new ParseIntPipe({ optional: true })) clubTypeId?: number,
    @Query('categoryId', new ParseIntPipe({ optional: true })) categoryId?: number,
    @Query('page', new ParseIntPipe({ optional: true })) page?: number,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    const pagination = new PaginationDto();
    if (page) pagination.page = page;
    if (limit) pagination.limit = Math.min(limit, 100);

    return this.financesService.findByClub(
      clubId,
      { year, month, clubTypeId, categoryId },
      pagination,
    );
  }

  @Get('clubs/:clubId/finances/summary')
  @ApiOperation({
    summary: 'Resumen financiero del club',
    description: 'Obtiene el resumen de ingresos, egresos y balance',
  })
  @ApiParam({ name: 'clubId', type: Number })
  @ApiQuery({ name: 'year', required: false, type: Number })
  @ApiQuery({ name: 'month', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Resumen financiero' })
  async getSummary(
    @Param('clubId', ParseIntPipe) clubId: number,
    @Query('year', new ParseIntPipe({ optional: true })) year?: number,
    @Query('month', new ParseIntPipe({ optional: true })) month?: number,
  ) {
    return this.financesService.getSummary(clubId, year, month);
  }

  @Post('clubs/:clubId/finances')
  @UseGuards(ClubRolesGuard)
  @ClubRoles('director', 'subdirector', 'treasurer')
  @ApiOperation({
    summary: 'Crear movimiento financiero',
    description: 'Crea un nuevo ingreso o egreso (requiere rol de tesorería)',
  })
  @ApiParam({ name: 'clubId', type: Number })
  @ApiResponse({ status: 201, description: 'Movimiento creado' })
  @ApiResponse({ status: 403, description: 'Permisos insuficientes' })
  async create(
    @Param('clubId', ParseIntPipe) clubId: number,
    @Body() dto: CreateFinanceDto,
    @Request() req: any,
  ) {
    return this.financesService.create(dto, req.user.sub);
  }

  // ========================================
  // MOVIMIENTO INDIVIDUAL
  // ========================================

  @Get('finances/:financeId')
  @ApiOperation({ summary: 'Obtener movimiento por ID' })
  @ApiParam({ name: 'financeId', type: Number })
  @ApiResponse({ status: 200, description: 'Movimiento encontrado' })
  @ApiResponse({ status: 404, description: 'Movimiento no encontrado' })
  async findOne(@Param('financeId', ParseIntPipe) financeId: number) {
    return this.financesService.findOne(financeId);
  }

  @Patch('finances/:financeId')
  @ApiOperation({ summary: 'Actualizar movimiento' })
  @ApiParam({ name: 'financeId', type: Number })
  @ApiResponse({ status: 200, description: 'Movimiento actualizado' })
  async update(
    @Param('financeId', ParseIntPipe) financeId: number,
    @Body() dto: UpdateFinanceDto,
  ) {
    return this.financesService.update(financeId, dto);
  }

  @Delete('finances/:financeId')
  @ApiOperation({ summary: 'Desactivar movimiento' })
  @ApiParam({ name: 'financeId', type: Number })
  @ApiResponse({ status: 200, description: 'Movimiento desactivado' })
  async remove(@Param('financeId', ParseIntPipe) financeId: number) {
    return this.financesService.remove(financeId);
  }
}
