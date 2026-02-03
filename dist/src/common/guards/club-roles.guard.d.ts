import { CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../../prisma/prisma.service';
export declare const CLUB_ROLES_KEY = "club_roles";
export type ClubRoleType = 'director' | 'subdirector' | 'secretary' | 'treasurer' | 'counselor' | 'instructor' | 'captain' | 'member';
export declare class ClubRolesGuard implements CanActivate {
    private readonly reflector;
    private readonly prisma;
    constructor(reflector: Reflector, prisma: PrismaService);
    canActivate(context: ExecutionContext): Promise<boolean>;
    private extractClubId;
    private checkUserClubRole;
}
