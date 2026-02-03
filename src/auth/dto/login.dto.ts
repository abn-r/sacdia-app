import { IsEmail, IsString } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class LoginDto {
  @ApiProperty({
    example: 'juan.garcia@example.com',
    description: 'Correo electrónico',
  })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'Password123!', description: 'Contraseña' })
  @IsString()
  password: string;
}
