import {
  IsOptional,
  IsString,
  IsIn,
  IsDateString,
  IsBoolean,
  ValidateIf,
  IsEnum,
} from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { blood_type } from '@prisma/client';

export class UpdateUserDto {
  @ApiPropertyOptional({ example: 'M', enum: ['M', 'F'] })
  @IsOptional()
  @IsIn(['M', 'F'])
  gender?: 'M' | 'F';

  @ApiPropertyOptional({ example: '2000-01-15', description: 'Fecha de nacimiento (YYYY-MM-DD)' })
  @IsOptional()
  @IsDateString()
  birthday?: string;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  baptism?: boolean;

  @ApiPropertyOptional({
    example: '2015-06-20',
    description: 'Fecha de bautismo (requerido si baptism=true)',
  })
  @IsOptional()
  @IsDateString()
  @ValidateIf((o) => o.baptism === true)
  baptism_date?: string;

  @ApiPropertyOptional({ 
    example: 'A_POSITIVE', 
    enum: blood_type,
    description: 'Tipo de sangre' 
  })
  @IsOptional()
  @IsEnum(blood_type)
  blood?: blood_type;
}
