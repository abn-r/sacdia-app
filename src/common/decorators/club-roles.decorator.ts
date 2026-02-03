import { SetMetadata } from '@nestjs/common';
import { CLUB_ROLES_KEY, type ClubRoleType } from '../guards/club-roles.guard';

/**
 * Decorator to require specific club roles for an endpoint.
 *
 * @example
 * // Require director or subdirector role
 * @ClubRoles('director', 'subdirector')
 * @UseGuards(JwtAuthGuard, ClubRolesGuard)
 * @Post('clubs/:clubId/instances')
 * createInstance() { ... }
 */
export const ClubRoles = (...roles: ClubRoleType[]) =>
  SetMetadata(CLUB_ROLES_KEY, roles);

