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
var IpWhitelistGuard_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.IpWhitelistGuard = exports.AdminOnly = exports.ADMIN_ONLY_KEY = void 0;
const common_1 = require("@nestjs/common");
const core_1 = require("@nestjs/core");
exports.ADMIN_ONLY_KEY = 'adminOnly';
const AdminOnly = () => (target, key, descriptor) => {
    Reflect.defineMetadata(exports.ADMIN_ONLY_KEY, true, descriptor?.value ?? target);
    return descriptor ?? target;
};
exports.AdminOnly = AdminOnly;
let IpWhitelistGuard = IpWhitelistGuard_1 = class IpWhitelistGuard {
    reflector;
    logger = new common_1.Logger(IpWhitelistGuard_1.name);
    allowedIps;
    constructor(reflector) {
        this.reflector = reflector;
        const envIps = process.env.ADMIN_ALLOWED_IPS || '';
        this.allowedIps = envIps
            .split(',')
            .map((ip) => ip.trim())
            .filter((ip) => ip.length > 0);
        if (process.env.NODE_ENV !== 'production') {
            this.allowedIps.push('127.0.0.1', '::1', 'localhost', '::ffff:127.0.0.1');
        }
        this.logger.log(`IP Whitelist configured with ${this.allowedIps.length} IPs`);
    }
    canActivate(context) {
        const isAdminOnly = this.reflector.get(exports.ADMIN_ONLY_KEY, context.getHandler());
        if (!isAdminOnly) {
            return true;
        }
        const request = context.switchToHttp().getRequest();
        const clientIp = this.getClientIp(request);
        const isAllowed = this.isIpAllowed(clientIp);
        if (!isAllowed) {
            this.logger.warn(`IP ${clientIp} denied access to admin endpoint: ${request.method} ${request.url}`);
            throw new common_1.ForbiddenException('Access denied. Your IP is not authorized for this operation.');
        }
        this.logger.debug(`IP ${clientIp} allowed access to admin endpoint`);
        return true;
    }
    getClientIp(request) {
        const forwardedFor = request.headers['x-forwarded-for'];
        if (forwardedFor) {
            const ips = Array.isArray(forwardedFor)
                ? forwardedFor[0]
                : forwardedFor.split(',')[0];
            return ips.trim();
        }
        const realIp = request.headers['x-real-ip'];
        if (realIp) {
            return Array.isArray(realIp) ? realIp[0] : realIp;
        }
        return request.ip || request.socket.remoteAddress || 'unknown';
    }
    isIpAllowed(ip) {
        if (this.allowedIps.length === 0) {
            return process.env.NODE_ENV !== 'production';
        }
        const normalizedIp = ip.replace('::ffff:', '');
        return this.allowedIps.some((allowedIp) => {
            if (allowedIp.includes('/')) {
                return this.isIpInCidr(normalizedIp, allowedIp);
            }
            return allowedIp === ip || allowedIp === normalizedIp;
        });
    }
    isIpInCidr(ip, cidr) {
        const [range, bits] = cidr.split('/');
        const mask = ~(2 ** (32 - parseInt(bits, 10)) - 1);
        const ipNum = this.ipToNumber(ip);
        const rangeNum = this.ipToNumber(range);
        if (ipNum === null || rangeNum === null)
            return false;
        return (ipNum & mask) === (rangeNum & mask);
    }
    ipToNumber(ip) {
        const parts = ip.split('.');
        if (parts.length !== 4)
            return null;
        return parts.reduce((acc, octet) => {
            const num = parseInt(octet, 10);
            if (isNaN(num) || num < 0 || num > 255)
                return NaN;
            return (acc << 8) + num;
        }, 0);
    }
};
exports.IpWhitelistGuard = IpWhitelistGuard;
exports.IpWhitelistGuard = IpWhitelistGuard = IpWhitelistGuard_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [core_1.Reflector])
], IpWhitelistGuard);
//# sourceMappingURL=ip-whitelist.guard.js.map