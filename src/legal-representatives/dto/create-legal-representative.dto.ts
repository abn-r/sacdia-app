import {
  IsOptional,
  IsUUID,
  IsString,
  MaxLength,
  ValidateIf,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateLegalRepresentativeDto {
  @ApiPropertyOptional({
    description: 'ID del usuario registrado que es el representante legal',
  })
  @IsOptional()
  @IsUUID()
  representative_user_id?: string;

  @ApiPropertyOptional({
    description: 'Nombre (requerido si no se proporciona representative_user_id)',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  @ValidateIf((o) => !o.representative_user_id)
  name?: string;

  @ApiPropertyOptional({
    description: 'Apellido paterno (requerido si no se proporciona representative_user_id)',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  @ValidateIf((o) => !o.representative_user_id)
  paternal_last_name?: string;

  @ApiPropertyOptional({ description: 'Apellido materno' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  maternal_last_name?: string;

  @ApiPropertyOptional({
    description: 'Teléfono (requerido si no se proporciona representative_user_id)',
  })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  @ValidateIf((o) => !o.representative_user_id)
  phone?: string;

  @ApiProperty({ description: 'UUID del tipo de relación' })
  @IsUUID()
  relationship_type_id: string;
}
