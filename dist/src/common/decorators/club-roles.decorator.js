"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ClubRoles = void 0;
const common_1 = require("@nestjs/common");
const club_roles_guard_1 = require("../guards/club-roles.guard");
const ClubRoles = (...roles) => (0, common_1.SetMetadata)(club_roles_guard_1.CLUB_ROLES_KEY, roles);
exports.ClubRoles = ClubRoles;
//# sourceMappingURL=club-roles.decorator.js.map