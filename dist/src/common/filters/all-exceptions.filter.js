"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AllExceptionsFilter = void 0;
const common_1 = require("@nestjs/common");
let AllExceptionsFilter = class AllExceptionsFilter {
    logger = new common_1.Logger('UnhandledException');
    catch(exception, host) {
        const ctx = host.switchToHttp();
        const response = ctx.getResponse();
        const request = ctx.getRequest();
        const errorMessage = exception instanceof Error ? exception.message : 'Unknown error';
        const errorStack = exception instanceof Error ? exception.stack : undefined;
        this.logger.error(JSON.stringify({
            timestamp: new Date().toISOString(),
            method: request.method,
            url: request.url,
            message: errorMessage,
            stack: process.env.NODE_ENV === 'development' ? errorStack : undefined,
        }));
        response.status(common_1.HttpStatus.INTERNAL_SERVER_ERROR).json({
            status: 'error',
            statusCode: common_1.HttpStatus.INTERNAL_SERVER_ERROR,
            message: process.env.NODE_ENV === 'production'
                ? 'Internal server error'
                : errorMessage,
            timestamp: new Date().toISOString(),
            path: request.url,
        });
    }
};
exports.AllExceptionsFilter = AllExceptionsFilter;
exports.AllExceptionsFilter = AllExceptionsFilter = __decorate([
    (0, common_1.Catch)()
], AllExceptionsFilter);
//# sourceMappingURL=all-exceptions.filter.js.map