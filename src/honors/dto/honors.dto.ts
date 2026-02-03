import { IsInt, IsOptional, IsString, IsBoolean, IsArray, IsDateString } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class StartHonorDto {
  @ApiPropertyOptional({ description: 'Fecha de inicio del honor' })
  @IsOptional()
  @IsDateString()
  date?: string;
}

export class UpdateUserHonorDto {
  @ApiPropertyOptional({ description: 'Honor validado por instructor' })
  @IsOptional()
  @IsBoolean()
  validate?: boolean;

  @ApiPropertyOptional({ description: 'URL del certificado' })
  @IsOptional()
  @IsString()
  certificate?: string;

  @ApiPropertyOptional({ description: 'URLs de imágenes de evidencia' })
  @IsOptional()
  @IsArray()
  images?: string[];

  @ApiPropertyOptional({ description: 'URL del documento adicional' })
  @IsOptional()
  @IsString()
  document?: string;

  @ApiPropertyOptional({ description: 'Fecha de completación' })
  @IsOptional()
  @IsDateString()
  date?: string;
}

export class HonorFiltersDto {
  @ApiPropertyOptional({ description: 'Filtrar por categoría de honor' })
  @IsOptional()
  @IsInt()
  categoryId?: number;

  @ApiPropertyOptional({ description: 'Filtrar por tipo de club' })
  @IsOptional()
  @IsInt()
  clubTypeId?: number;

  @ApiPropertyOptional({ description: 'Filtrar por nivel de habilidad (1-3)' })
  @IsOptional()
  @IsInt()
  skillLevel?: number;
}
