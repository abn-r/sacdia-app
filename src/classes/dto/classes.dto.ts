import {
  IsInt,
  IsOptional,
  IsNumber,
  IsObject,
  Min,
  Max,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class EnrollClassDto {
  @ApiProperty({ description: 'ID de la clase' })
  @IsInt()
  class_id: number;

  @ApiProperty({ description: 'ID del año eclesiástico' })
  @IsInt()
  ecclesiastical_year_id: number;
}

export class UpdateProgressDto {
  @ApiProperty({ description: 'ID del módulo' })
  @IsInt()
  module_id: number;

  @ApiProperty({ description: 'ID de la sección' })
  @IsInt()
  section_id: number;

  @ApiProperty({
    description: 'Puntaje obtenido (0-100)',
    minimum: 0,
    maximum: 100,
  })
  @IsNumber()
  @Min(0)
  @Max(100)
  score: number;

  @ApiPropertyOptional({
    description: 'Evidencias en formato JSON (URLs, notas, etc.)',
  })
  @IsOptional()
  @IsObject()
  evidences?: Record<string, unknown>;
}
