import { Controller, Get, Query, ParseIntPipe } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiQuery,
} from '@nestjs/swagger';
import { CatalogsService } from './catalogs.service';

@ApiTags('catalogs')
@Controller('catalogs')
export class CatalogsController {
  constructor(private readonly catalogsService: CatalogsService) {}

  // ========================================
  // CLUB TYPES
  // ========================================
  @Get('club-types')
  @ApiOperation({
    summary: 'Obtener tipos de club',
    description: 'Lista los tipos de club disponibles (Aventureros, Conquistadores, Guías Mayores)',
  })
  @ApiResponse({ status: 200, description: 'Lista de tipos de club' })
  async getClubTypes() {
    return this.catalogsService.getClubTypes();
  }

  // ========================================
  // COUNTRIES
  // ========================================
  @Get('countries')
  @ApiOperation({
    summary: 'Obtener países',
    description: 'Lista todos los países activos',
  })
  @ApiResponse({ status: 200, description: 'Lista de países' })
  async getCountries() {
    return this.catalogsService.getCountries();
  }

  // ========================================
  // UNIONS
  // ========================================
  @Get('unions')
  @ApiOperation({
    summary: 'Obtener uniones',
    description: 'Lista uniones de la organización, opcionalmente filtradas por país',
  })
  @ApiQuery({
    name: 'countryId',
    required: false,
    type: Number,
    description: 'ID del país para filtrar',
  })
  @ApiResponse({ status: 200, description: 'Lista de uniones' })
  async getUnions(
    @Query('countryId', new ParseIntPipe({ optional: true }))
    countryId?: number,
  ) {
    return this.catalogsService.getUnions(countryId);
  }

  // ========================================
  // LOCAL FIELDS
  // ========================================
  @Get('local-fields')
  @ApiOperation({
    summary: 'Obtener campos locales',
    description: 'Lista campos locales, opcionalmente filtrados por unión',
  })
  @ApiQuery({
    name: 'unionId',
    required: false,
    type: Number,
    description: 'ID de la unión para filtrar',
  })
  @ApiResponse({ status: 200, description: 'Lista de campos locales' })
  async getLocalFields(
    @Query('unionId', new ParseIntPipe({ optional: true }))
    unionId?: number,
  ) {
    return this.catalogsService.getLocalFields(unionId);
  }

  // ========================================
  // DISTRICTS
  // ========================================
  @Get('districts')
  @ApiOperation({
    summary: 'Obtener distritos',
    description: 'Lista distritos, opcionalmente filtrados por campo local',
  })
  @ApiQuery({
    name: 'localFieldId',
    required: false,
    type: Number,
    description: 'ID del campo local para filtrar',
  })
  @ApiResponse({ status: 200, description: 'Lista de distritos' })
  async getDistricts(
    @Query('localFieldId', new ParseIntPipe({ optional: true }))
    localFieldId?: number,
  ) {
    return this.catalogsService.getDistricts(localFieldId);
  }

  // ========================================
  // CHURCHES
  // ========================================
  @Get('churches')
  @ApiOperation({
    summary: 'Obtener iglesias',
    description: 'Lista iglesias, opcionalmente filtradas por distrito',
  })
  @ApiQuery({
    name: 'districtId',
    required: false,
    type: Number,
    description: 'ID del distrito para filtrar',
  })
  @ApiResponse({ status: 200, description: 'Lista de iglesias' })
  async getChurches(
    @Query('districtId', new ParseIntPipe({ optional: true }))
    districtId?: number,
  ) {
    return this.catalogsService.getChurches(districtId);
  }

  // ========================================
  // ROLES
  // ========================================
  @Get('roles')
  @ApiOperation({
    summary: 'Obtener roles disponibles',
    description: 'Lista roles del sistema, opcionalmente filtrados por categoría (GLOBAL o CLUB)',
  })
  @ApiQuery({
    name: 'category',
    required: false,
    type: String,
    enum: ['GLOBAL', 'CLUB'],
    description: 'Categoría de rol para filtrar',
  })
  @ApiResponse({ status: 200, description: 'Lista de roles' })
  async getRoles(@Query('category') category?: string) {
    return this.catalogsService.getRoles(category);
  }

  // ========================================
  // ECCLESIASTICAL YEARS
  // ========================================
  @Get('ecclesiastical-years')
  @ApiOperation({
    summary: 'Obtener años eclesiásticos',
    description: 'Lista todos los años eclesiásticos registrados',
  })
  @ApiResponse({ status: 200, description: 'Lista de años eclesiásticos' })
  async getEcclesiasticalYears() {
    return this.catalogsService.getEcclesiasticalYears();
  }

  @Get('ecclesiastical-years/current')
  @ApiOperation({
    summary: 'Obtener año eclesiástico actual',
    description: 'Retorna el año eclesiástico vigente basado en la fecha actual',
  })
  @ApiResponse({ status: 200, description: 'Año eclesiástico actual' })
  async getCurrentEcclesiasticalYear() {
    return this.catalogsService.getCurrentEcclesiasticalYear();
  }

  // ========================================
  // CLUB IDEALS
  // ========================================
  @Get('club-ideals')
  @ApiOperation({
    summary: 'Obtener ideales de club',
    description: 'Lista los ideales (ley, voto, lema, etc.) por tipo de club',
  })
  @ApiQuery({
    name: 'clubTypeId',
    required: false,
    type: Number,
    description: 'ID del tipo de club para filtrar',
  })
  @ApiResponse({ status: 200, description: 'Lista de ideales' })
  async getClubIdeals(
    @Query('clubTypeId', new ParseIntPipe({ optional: true }))
    clubTypeId?: number,
  ) {
    return this.catalogsService.getClubIdeals(clubTypeId);
  }
}
