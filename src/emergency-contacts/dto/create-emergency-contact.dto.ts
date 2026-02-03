import { IsString, IsInt, IsBoolean, IsOptional, MaxLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateEmergencyContactDto {
  @ApiProperty({ example: 'María García López' })
  @IsString()
  @MaxLength(100)
  name: string;

  @ApiProperty({ 
    example: 1, 
    description: 'ID del tipo de relación (actualmente Int, pendiente migración a UUID)' 
  })
  @IsInt()
  relationship_type: number;

  @ApiProperty({ example: '+52 55 1234 5678' })
  @IsString()
  @MaxLength(20)
  phone: string;

  @ApiPropertyOptional({ example: true, description: 'Si es el contacto principal' })
  @IsOptional()
  @IsBoolean()
  primary?: boolean;
}
