"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.EmergencyContactsModule = void 0;
const common_1 = require("@nestjs/common");
const emergency_contacts_service_1 = require("./emergency-contacts.service");
const emergency_contacts_controller_1 = require("./emergency-contacts.controller");
let EmergencyContactsModule = class EmergencyContactsModule {
};
exports.EmergencyContactsModule = EmergencyContactsModule;
exports.EmergencyContactsModule = EmergencyContactsModule = __decorate([
    (0, common_1.Module)({
        providers: [emergency_contacts_service_1.EmergencyContactsService],
        controllers: [emergency_contacts_controller_1.EmergencyContactsController]
    })
], EmergencyContactsModule);
//# sourceMappingURL=emergency-contacts.module.js.map