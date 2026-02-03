import {
  IsString,
  IsOptional,
  IsInt,
  IsBoolean,
  MaxLength,
  IsObject,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateClubDto {
  @ApiProperty({ example: 'Club Central', description: 'Nombre del club' })
  @IsString()
  @MaxLength(50)
  name: string;

  @ApiPropertyOptional({ description: 'Descripción del club' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ example: 1, description: 'ID del campo local' })
  @IsInt()
  local_field_id: number;

  @ApiProperty({ example: 1, description: 'ID del distrito' })
  @IsInt()
  districlub_type_id: number;

  @ApiProperty({ example: 1, description: 'ID de la iglesia' })
  @IsInt()
  church_id: number;

  @ApiPropertyOptional({ description: 'Dirección del club' })
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional({
    example: { lat: 19.4326, lng: -99.1332 },
    description: 'Coordenadas del club',
  })
  @IsOptional()
  @IsObject()
  coordinates?: { lat: number; lng: number };
}

export class UpdateClubDto {
  @ApiPropertyOptional({ example: 'Club Actualizado' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  name?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsObject()
  coordinates?: { lat: number; lng: number };

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
