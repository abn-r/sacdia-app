import {
  Controller,
  Get,
  Patch,
  Post,
  Delete,
  Param,
  Body,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  ParseFilePipe,
  MaxFileSizeValidator,
  FileTypeValidator,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiConsumes,
  ApiBody,
} from '@nestjs/swagger';
import { UsersService } from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('users')
@Controller('users')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get(':userId')
  @ApiOperation({ summary: 'Obtener información de un usuario' })
  @ApiResponse({ status: 200, description: 'Usuario encontrado' })
  @ApiResponse({ status: 404, description: 'Usuario no encontrado' })
  async findOne(@Param('userId') userId: string) {
    return this.usersService.findOne(userId);
  }

  @Patch(':userId')
  @ApiOperation({ summary: 'Actualizar información personal del usuario' })
  @ApiResponse({ status: 200, description: 'Usuario actualizado' })
  @ApiResponse({ status: 404, description: 'Usuario no encontrado' })
  async update(
    @Param('userId') userId: string,
    @Body() updateUserDto: UpdateUserDto,
  ) {
    return this.usersService.update(userId, updateUserDto);
  }

  @Post(':userId/profile-picture')
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Subir foto de perfil' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: {
          type: 'string',
          format: 'binary',
        },
      },
    },
  })
  @ApiResponse({ status: 201, description: 'Foto subida exitosamente' })
  @ApiResponse({ status: 400, description: 'Formato o tamaño inválido' })
  async uploadProfilePicture(
    @Param('userId') userId: string,
    @UploadedFile(
      new ParseFilePipe({
        validators: [
          new MaxFileSizeValidator({ maxSize: 5 * 1024 * 1024 }), // 5MB
          new FileTypeValidator({ fileType: /(jpg|jpeg|png|webp)$/ }),
        ],
      }),
    )
    file: Express.Multer.File,
  ) {
    return this.usersService.uploadProfilePicture(userId, file);
  }

  @Delete(':userId/profile-picture')
  @ApiOperation({ summary: 'Eliminar foto de perfil' })
  @ApiResponse({ status: 200, description: 'Foto eliminada' })
  @ApiResponse({ status: 404, description: 'Usuario sin foto de perfil' })
  async deleteProfilePicture(@Param('userId') userId: string) {
    return this.usersService.deleteProfilePicture(userId);
  }

  @Get(':userId/age')
  @ApiOperation({ summary: 'Calcular edad del usuario' })
  @ApiResponse({ status: 200, description: 'Edad calculada' })
  async getAge(@Param('userId') userId: string) {
    const age = await this.usersService.calculateAge(userId);
    return {
      status: 'success',
      data: { age },
    };
  }

  @Get(':userId/requires-legal-representative')
  @ApiOperation({
    summary: 'Verificar si el usuario requiere representante legal',
  })
  @ApiResponse({
    status: 200,
    description: 'Si requiere (edad < 18) o no',
  })
  async requiresLegalRepresentative(@Param('userId') userId: string) {
    const age = await this.usersService.calculateAge(userId);
    const required = await this.usersService.requiresLegalRepresentative(
      userId,
    );

    return {
      status: 'success',
      data: {
        required,
        userAge: age,
        reason: required
          ? 'Usuario es menor de 18 años'
          : 'Usuario es mayor de edad',
      },
    };
  }
}
