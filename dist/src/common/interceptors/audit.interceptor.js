"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuditInterceptor = void 0;
const common_1 = require("@nestjs/common");
const operators_1 = require("rxjs/operators");
let AuditInterceptor = class AuditInterceptor {
    logger = new common_1.Logger('AuditLog');
    intercept(context, next) {
        const request = context.switchToHttp().getRequest();
        const { method, url, ip, headers } = request;
        const user = request.user;
        const startTime = Date.now();
        const userAgent = headers['user-agent'] || 'unknown';
        return next.handle().pipe((0, operators_1.tap)({
            next: () => {
                const duration = Date.now() - startTime;
                this.logger.log(JSON.stringify({
                    timestamp: new Date().toISOString(),
                    userId: user?.user_id || 'anonymous',
                    method,
                    url: this.sanitizeUrl(url),
                    ip: this.getClientIp(request),
                    userAgent: userAgent.substring(0, 100),
                    duration: `${duration}ms`,
                    status: 'success',
                }));
            },
            error: (error) => {
                const duration = Date.now() - startTime;
                this.logger.warn(JSON.stringify({
                    timestamp: new Date().toISOString(),
                    userId: user?.user_id || 'anonymous',
                    method,
                    url: this.sanitizeUrl(url),
                    ip: this.getClientIp(request),
                    userAgent: userAgent.substring(0, 100),
                    duration: `${duration}ms`,
                    status: 'error',
                    errorMessage: error.message,
                }));
            },
        }));
    }
    getClientIp(request) {
        return (request.headers['x-forwarded-for']?.split(',')[0]?.trim() ||
            request.headers['x-real-ip'] ||
            request.ip ||
            'unknown');
    }
    sanitizeUrl(url) {
        return url.split('?')[0];
    }
};
exports.AuditInterceptor = AuditInterceptor;
exports.AuditInterceptor = AuditInterceptor = __decorate([
    (0, common_1.Injectable)()
], AuditInterceptor);
//# sourceMappingURL=audit.interceptor.js.map