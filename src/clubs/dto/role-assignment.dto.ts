import { IsString, IsDate, IsOptional, IsUUID } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ClubInstanceType } from './instance.dto';

export class AssignRoleDto {
  @ApiProperty({ description: 'ID del usuario' })
  @IsUUID()
  user_id: string;

  @ApiProperty({ description: 'ID del rol a asignar' })
  @IsUUID()
  role_id: string;

  @ApiProperty({
    enum: ClubInstanceType,
    description: 'Tipo de instancia de club',
  })
  instance_type: ClubInstanceType;

  @ApiProperty({ description: 'ID de la instancia de club' })
  instance_id: number;

  @ApiProperty({ description: 'ID del año eclesiástico' })
  ecclesiastical_year_id: number;

  @ApiProperty({ description: 'Fecha de inicio del rol' })
  @IsDate()
  @Type(() => Date)
  start_date: Date;

  @ApiPropertyOptional({ description: 'Fecha de fin del rol' })
  @IsOptional()
  @IsDate()
  @Type(() => Date)
  end_date?: Date;
}

export class UpdateRoleAssignmentDto {
  @ApiPropertyOptional({ description: 'Fecha de fin del rol' })
  @IsOptional()
  @IsDate()
  @Type(() => Date)
  end_date?: Date;

  @ApiPropertyOptional({ description: 'Estado del rol' })
  @IsOptional()
  @IsString()
  status?: string;
}
