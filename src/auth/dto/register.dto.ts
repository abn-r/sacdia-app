import {
  IsEmail,
  IsString,
  MinLength,
  MaxLength,
  Matches,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RegisterDto {
  @ApiProperty({ example: 'Juan', description: 'Nombre del usuario' })
  @IsString()
  @MaxLength(50)
  name: string;

  @ApiProperty({ example: 'García', description: 'Apellido paterno' })
  @IsString()
  @MaxLength(50)
  paternal_last_name: string;

  @ApiProperty({ example: 'López', description: 'Apellido materno' })
  @IsString()
  @MaxLength(50)
  maternal_last_name: string;

  @ApiProperty({
    example: 'juan.garcia@example.com',
    description: 'Correo electrónico',
  })
  @IsEmail()
  email: string;

  @ApiProperty({
    example: 'Password123!',
    description:
      'Contraseña segura (mínimo 8 caracteres, debe incluir mayúscula, minúscula, número y carácter especial)',
  })
  @IsString()
  @MinLength(8, { message: 'La contraseña debe tener al menos 8 caracteres' })
  @Matches(
    /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
    {
      message:
        'La contraseña debe incluir: mayúscula, minúscula, número y carácter especial (@$!%*?&)',
    },
  )
  password: string;
}

