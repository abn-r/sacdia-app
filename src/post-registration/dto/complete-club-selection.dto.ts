import { IsInt, IsIn } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CompleteClubSelectionDto {
  @ApiProperty({ example: 1, description: 'ID del país' })
  @IsInt()
  country_id: number;

  @ApiProperty({ example: 1, description: 'ID de la unión' })
  @IsInt()
  union_id: number;

  @ApiProperty({ example: 1, description: 'ID del campo local' })
  @IsInt()
  local_field_id: number;

  @ApiProperty({
    example: 'adventurers',
    enum: ['adventurers', 'pathfinders', 'master_guild'],
    description: 'Tipo de club',
  })
  @IsIn(['adventurers', 'pathfinders', 'master_guild'])
  club_type: 'adventurers' | 'pathfinders' | 'master_guild';

  @ApiProperty({
    example: 1,
    description: 'ID de la instancia del club (club_adv_id, club_pathf_id, o club_mg_id)',
  })
  @IsInt()
  club_instance_id: number;

  @ApiProperty({
    example: 1,
    description: 'ID de la clase a inscribirse',
  })
  @IsInt()
  class_id: number;
}
