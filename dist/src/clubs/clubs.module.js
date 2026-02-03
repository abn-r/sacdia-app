"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ClubsModule = void 0;
const common_1 = require("@nestjs/common");
const clubs_controller_1 = require("./clubs.controller");
const clubs_service_1 = require("./clubs.service");
const prisma_module_1 = require("../prisma/prisma.module");
const guards_1 = require("../common/guards");
let ClubsModule = class ClubsModule {
};
exports.ClubsModule = ClubsModule;
exports.ClubsModule = ClubsModule = __decorate([
    (0, common_1.Module)({
        imports: [prisma_module_1.PrismaModule],
        controllers: [clubs_controller_1.ClubsController, clubs_controller_1.ClubRolesController],
        providers: [clubs_service_1.ClubsService, guards_1.ClubRolesGuard],
        exports: [clubs_service_1.ClubsService],
    })
], ClubsModule);
//# sourceMappingURL=clubs.module.js.map