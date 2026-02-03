import {
  IsInt,
  IsOptional,
  IsArray,
  IsBoolean,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';

// Tipo de club
export enum ClubInstanceType {
  ADVENTURERS = 'adventurers',
  PATHFINDERS = 'pathfinders',
  MASTER_GUILDS = 'master_guilds',
}

export class CreateInstanceDto {
  @ApiProperty({
    enum: ClubInstanceType,
    example: 'pathfinders',
    description: 'Tipo de instancia a crear',
  })
  type: ClubInstanceType;

  @ApiPropertyOptional({ example: 1, description: 'Meta de almas' })
  @IsOptional()
  @IsInt()
  souls_target?: number;

  @ApiPropertyOptional({ example: 100, description: 'Cuota mensual' })
  @IsOptional()
  @IsInt()
  fee?: number;

  @ApiPropertyOptional({
    example: [{ day: 'Saturday' }],
    description: 'Días de reunión',
  })
  @IsOptional()
  @IsArray()
  meeting_day?: Record<string, unknown>[];

  @ApiPropertyOptional({
    example: [{ time: '09:00' }],
    description: 'Horarios de reunión',
  })
  @IsOptional()
  @IsArray()
  meeting_time?: Record<string, unknown>[];
}

export class UpdateInstanceDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  souls_target?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  fee?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsArray()
  meeting_day?: Record<string, unknown>[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsArray()
  meeting_time?: Record<string, unknown>[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
