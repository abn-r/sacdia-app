import { IsEmail } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class ResetPasswordRequestDto {
  @ApiProperty({
    example: 'juan.garcia@example.com',
    description: 'Correo para recuperación',
  })
  @IsEmail()
  email: string;
}
