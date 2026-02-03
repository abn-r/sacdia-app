import { PartialType } from '@nestjs/swagger';
import { CreateLegalRepresentativeDto } from './create-legal-representative.dto';

export class UpdateLegalRepresentativeDto extends PartialType(
  CreateLegalRepresentativeDto,
) {}
