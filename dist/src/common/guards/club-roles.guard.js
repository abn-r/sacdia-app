"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ClubRolesGuard = exports.CLUB_ROLES_KEY = void 0;
const common_1 = require("@nestjs/common");
const core_1 = require("@nestjs/core");
const prisma_service_1 = require("../../prisma/prisma.service");
exports.CLUB_ROLES_KEY = 'club_roles';
let ClubRolesGuard = class ClubRolesGuard {
    reflector;
    prisma;
    constructor(reflector, prisma) {
        this.reflector = reflector;
        this.prisma = prisma;
    }
    async canActivate(context) {
        const requiredRoles = this.reflector.getAllAndOverride(exports.CLUB_ROLES_KEY, [context.getHandler(), context.getClass()]);
        if (!requiredRoles || requiredRoles.length === 0) {
            return true;
        }
        const request = context.switchToHttp().getRequest();
        const user = request.user;
        if (!user || !user.sub) {
            throw new common_1.ForbiddenException('User not authenticated');
        }
        const clubId = this.extractClubId(request);
        if (!clubId) {
            throw new common_1.ForbiddenException('Club ID not found in request');
        }
        const hasRole = await this.checkUserClubRole(user.sub, clubId, requiredRoles);
        if (!hasRole) {
            throw new common_1.ForbiddenException(`You need one of these club roles: ${requiredRoles.join(', ')}`);
        }
        return true;
    }
    extractClubId(request) {
        if (request.params?.clubId) {
            return parseInt(request.params.clubId, 10);
        }
        if (request.body?.club_id) {
            return parseInt(request.body.club_id, 10);
        }
        if (request.query?.clubId) {
            return parseInt(request.query.clubId, 10);
        }
        return null;
    }
    async checkUserClubRole(userId, clubId, requiredRoles) {
        const club = await this.prisma.clubs.findUnique({
            where: { club_id: clubId },
            select: {
                club_adventurers: { select: { club_adv_id: true } },
                club_pathfinders: { select: { club_pathf_id: true } },
                club_master_guild: { select: { club_mg_id: true } },
            },
        });
        if (!club) {
            return false;
        }
        const advIds = club.club_adventurers.map((a) => a.club_adv_id);
        const pathfIds = club.club_pathfinders.map((p) => p.club_pathf_id);
        const mgIds = club.club_master_guild.map((m) => m.club_mg_id);
        const assignments = await this.prisma.club_role_assignments.findMany({
            where: {
                user_id: userId,
                active: true,
                status: 'active',
                OR: [
                    { club_adv_id: { in: advIds.length > 0 ? advIds : [-1] } },
                    { club_pathf_id: { in: pathfIds.length > 0 ? pathfIds : [-1] } },
                    { club_mg_id: { in: mgIds.length > 0 ? mgIds : [-1] } },
                ],
            },
            include: {
                roles: { select: { role_name: true } },
            },
        });
        const userRoleNames = assignments.map((a) => a.roles.role_name.toLowerCase());
        return requiredRoles.some((requiredRole) => userRoleNames.includes(requiredRole.toLowerCase()));
    }
};
exports.ClubRolesGuard = ClubRolesGuard;
exports.ClubRolesGuard = ClubRolesGuard = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [core_1.Reflector,
        prisma_service_1.PrismaService])
], ClubRolesGuard);
//# sourceMappingURL=club-roles.guard.js.map