"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.HttpExceptionFilter = void 0;
const common_1 = require("@nestjs/common");
let HttpExceptionFilter = class HttpExceptionFilter {
    logger = new common_1.Logger('HttpException');
    catch(exception, host) {
        const ctx = host.switchToHttp();
        const response = ctx.getResponse();
        const request = ctx.getRequest();
        const status = exception.getStatus();
        const exceptionResponse = exception.getResponse();
        this.logger.error(JSON.stringify({
            timestamp: new Date().toISOString(),
            method: request.method,
            url: request.url,
            status,
            message: exception.message,
            stack: process.env.NODE_ENV === 'development'
                ? exception.stack
                : undefined,
        }));
        if (process.env.NODE_ENV === 'production') {
            response.status(status).json({
                status: 'error',
                statusCode: status,
                message: status >= common_1.HttpStatus.INTERNAL_SERVER_ERROR
                    ? 'Internal server error'
                    : this.extractMessage(exceptionResponse),
                timestamp: new Date().toISOString(),
                path: request.url,
            });
        }
        else {
            response.status(status).json({
                status: 'error',
                statusCode: status,
                message: exception.message,
                details: typeof exceptionResponse === 'object'
                    ? exceptionResponse
                    : { message: exceptionResponse },
                timestamp: new Date().toISOString(),
                path: request.url,
            });
        }
    }
    extractMessage(response) {
        if (typeof response === 'string') {
            return response;
        }
        if (typeof response === 'object' && 'message' in response) {
            const message = response.message;
            return Array.isArray(message) ? message[0] : message;
        }
        return 'An error occurred';
    }
};
exports.HttpExceptionFilter = HttpExceptionFilter;
exports.HttpExceptionFilter = HttpExceptionFilter = __decorate([
    (0, common_1.Catch)(common_1.HttpException)
], HttpExceptionFilter);
//# sourceMappingURL=http-exception.filter.js.map