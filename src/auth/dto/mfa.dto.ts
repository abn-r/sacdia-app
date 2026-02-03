import { IsString, Length } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class VerifyMfaDto {
  @ApiProperty({
    example: 'abc123-factor-id',
    description: 'ID del factor MFA a verificar',
  })
  @IsString()
  factorId: string;

  @ApiProperty({
    example: '123456',
    description: 'Código TOTP de 6 dígitos de tu app de autenticación',
  })
  @IsString()
  @Length(6, 6, { message: 'El código debe tener 6 dígitos' })
  code: string;
}

export class UnenrollMfaDto {
  @ApiProperty({
    example: 'abc123-factor-id',
    description: 'ID del factor MFA a eliminar',
  })
  @IsString()
  factorId: string;
}
