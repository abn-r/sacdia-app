"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SanitizePipe = void 0;
const common_1 = require("@nestjs/common");
const sanitize_html_1 = __importDefault(require("sanitize-html"));
let SanitizePipe = class SanitizePipe {
    transform(value, metadata) {
        if (metadata.type !== 'body') {
            return value;
        }
        return this.sanitizeValue(value);
    }
    sanitizeValue(value) {
        if (typeof value === 'string') {
            return (0, sanitize_html_1.default)(value, {
                allowedTags: [],
                allowedAttributes: {},
            });
        }
        if (Array.isArray(value)) {
            return value.map((item) => this.sanitizeValue(item));
        }
        if (typeof value === 'object' && value !== null) {
            return this.sanitizeObject(value);
        }
        return value;
    }
    sanitizeObject(obj) {
        const sanitized = {};
        for (const key of Object.keys(obj)) {
            sanitized[key] = this.sanitizeValue(obj[key]);
        }
        return sanitized;
    }
};
exports.SanitizePipe = SanitizePipe;
exports.SanitizePipe = SanitizePipe = __decorate([
    (0, common_1.Injectable)()
], SanitizePipe);
//# sourceMappingURL=sanitize.pipe.js.map