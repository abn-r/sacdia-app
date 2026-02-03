import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  UseGuards,
  ParseIntPipe,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { EmergencyContactsService } from './emergency-contacts.service';
import { CreateEmergencyContactDto } from './dto/create-emergency-contact.dto';
import { UpdateEmergencyContactDto } from './dto/update-emergency-contact.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';

@ApiTags('emergency-contacts')
@Controller('users/:userId/emergency-contacts')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class EmergencyContactsController {
  constructor(
    private readonly emergencyContactsService: EmergencyContactsService,
  ) {}

  @Post()
  @ApiOperation({ summary: 'Crear contacto de emergencia (máximo 5)' })
  @ApiResponse({ status: 201, description: 'Contacto creado' })
  @ApiResponse({ status: 400, description: 'Máximo de contactos alcanzado' })
  async create(
    @Param('userId') userId: string,
    @Body() createDto: CreateEmergencyContactDto,
  ) {
    return this.emergencyContactsService.create(userId, createDto);
  }

  @Get()
  @ApiOperation({ summary: 'Listar contactos de emergencia del usuario' })
  @ApiResponse({ status: 200, description: 'Lista de contactos' })
  async findAll(@Param('userId') userId: string) {
    return this.emergencyContactsService.findAll(userId);
  }

  @Get(':contactId')
  @ApiOperation({ summary: 'Obtener un contacto específico' })
  @ApiResponse({ status: 200, description: 'Contacto encontrado' })
  @ApiResponse({ status: 404, description: 'Contacto no encontrado' })
  async findOne(
    @Param('userId') userId: string,
    @Param('contactId', ParseIntPipe) contactId: number,
  ) {
    return this.emergencyContactsService.findOne(contactId, userId);
  }

  @Patch(':contactId')
  @ApiOperation({ summary: 'Actualizar contacto de emergencia' })
  @ApiResponse({ status: 200, description: 'Contacto actualizado' })
  @ApiResponse({ status: 404, description: 'Contacto no encontrado' })
  async update(
    @Param('userId') userId: string,
    @Param('contactId', ParseIntPipe) contactId: number,
    @Body() updateDto: UpdateEmergencyContactDto,
  ) {
    return this.emergencyContactsService.update(contactId, userId, updateDto);
  }

  @Delete(':contactId')
  @ApiOperation({ summary: 'Eliminar contacto de emergencia (soft delete)' })
  @ApiResponse({ status: 200, description: 'Contacto eliminado' })
  @ApiResponse({ status: 404, description: 'Contacto no encontrado' })
  async remove(
    @Param('userId') userId: string,
    @Param('contactId', ParseIntPipe) contactId: number,
  ) {
    return this.emergencyContactsService.remove(contactId, userId);
  }
}
