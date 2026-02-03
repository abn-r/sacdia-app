"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.CommonModule = void 0;
const common_1 = require("@nestjs/common");
const cache_manager_1 = require("@nestjs/cache-manager");
const token_blacklist_service_1 = require("./services/token-blacklist.service");
const session_management_service_1 = require("./services/session-management.service");
const mfa_service_1 = require("./services/mfa.service");
const ip_whitelist_guard_1 = require("./guards/ip-whitelist.guard");
let CommonModule = class CommonModule {
};
exports.CommonModule = CommonModule;
exports.CommonModule = CommonModule = __decorate([
    (0, common_1.Global)(),
    (0, common_1.Module)({
        imports: [
            cache_manager_1.CacheModule.register({
                ttl: 86400000,
                max: 10000,
                isGlobal: true,
            }),
        ],
        providers: [
            token_blacklist_service_1.TokenBlacklistService,
            session_management_service_1.SessionManagementService,
            mfa_service_1.MfaService,
            ip_whitelist_guard_1.IpWhitelistGuard,
        ],
        exports: [
            cache_manager_1.CacheModule,
            token_blacklist_service_1.TokenBlacklistService,
            session_management_service_1.SessionManagementService,
            mfa_service_1.MfaService,
            ip_whitelist_guard_1.IpWhitelistGuard,
        ],
    })
], CommonModule);
//# sourceMappingURL=common.module.js.map