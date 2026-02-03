"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const core_1 = require("@nestjs/core");
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const helmet_1 = __importDefault(require("helmet"));
const compression_1 = __importDefault(require("compression"));
const express_1 = require("express");
const app_module_1 = require("./app.module");
const sanitize_pipe_1 = require("./common/pipes/sanitize.pipe");
const audit_interceptor_1 = require("./common/interceptors/audit.interceptor");
const http_exception_filter_1 = require("./common/filters/http-exception.filter");
const all_exceptions_filter_1 = require("./common/filters/all-exceptions.filter");
async function bootstrap() {
    const app = await core_1.NestFactory.create(app_module_1.AppModule);
    const isDevelopment = process.env.NODE_ENV !== 'production';
    app.use((0, helmet_1.default)({
        contentSecurityPolicy: isDevelopment ? false : {
            directives: {
                defaultSrc: ["'self'"],
                styleSrc: ["'self'", "'unsafe-inline'", 'https://cdn.jsdelivr.net'],
                scriptSrc: ["'self'", "'unsafe-inline'", 'https://cdn.jsdelivr.net'],
                imgSrc: ["'self'", 'data:', 'https:'],
                fontSrc: ["'self'", 'https://cdn.jsdelivr.net'],
            },
        },
        crossOriginEmbedderPolicy: false,
        hsts: isDevelopment ? false : {
            maxAge: 31536000,
            includeSubDomains: true,
        },
    }));
    app.use((0, compression_1.default)());
    app.use((0, express_1.json)({ limit: '10mb' }));
    app.use((0, express_1.urlencoded)({ extended: true, limit: '10mb' }));
    const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [
        'http://localhost:5173',
        'http://localhost:3000',
    ];
    app.enableCors({
        origin: (origin, callback) => {
            if (!origin || allowedOrigins.includes(origin)) {
                callback(null, true);
            }
            else {
                callback(new Error('Not allowed by CORS'));
            }
        },
        methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
        credentials: true,
        allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
        maxAge: 3600,
    });
    app.useGlobalPipes(new sanitize_pipe_1.SanitizePipe(), new common_1.ValidationPipe({
        whitelist: true,
        transform: true,
        forbidNonWhitelisted: true,
    }));
    app.useGlobalFilters(new all_exceptions_filter_1.AllExceptionsFilter(), new http_exception_filter_1.HttpExceptionFilter());
    app.useGlobalInterceptors(new audit_interceptor_1.AuditInterceptor());
    app.enableVersioning({
        type: common_1.VersioningType.URI,
        defaultVersion: '1',
    });
    const config = new swagger_1.DocumentBuilder()
        .setTitle('SACDIA API')
        .setDescription(`## Sistema de Administración de Clubes de Conquistadores y Aventureros

### Módulos Disponibles
- **Auth**: Autenticación con Supabase + JWT
- **Users**: Gestión de perfiles de usuario
- **Catalogs**: Catálogos de referencia (países, iglesias, roles, etc.)
- **Clubs**: Gestión de clubes e instancias (Aventureros, Conquistadores, GM)
- **Classes**: Clases progresivas y seguimiento de progreso
- **Honors**: Especialidades y honores
- **Activities**: Actividades de club y asistencia
- **Finances**: Control financiero

### Autenticación
Todos los endpoints protegidos requieren Bearer Token (JWT de Supabase).

### Paginación
Los endpoints de listado soportan: \`?page=1&limit=20\`
`)
        .setVersion('2.2.0')
        .setContact('SACDIA Team', 'https://sacdia.app', 'dev@sacdia.app')
        .setLicense('Proprietary', '')
        .addBearerAuth()
        .addTag('auth', 'Autenticación y registro')
        .addTag('users', 'Gestión de usuarios')
        .addTag('emergency-contacts', 'Contactos de emergencia')
        .addTag('legal-representatives', 'Representantes legales')
        .addTag('post-registration', 'Post-registro y onboarding')
        .addTag('catalogs', 'Catálogos de referencia')
        .addTag('clubs', 'Gestión de clubes')
        .addTag('classes', 'Clases progresivas')
        .addTag('honors', 'Catálogo de honores/especialidades')
        .addTag('user-honors', 'Progreso de honores por usuario')
        .addTag('activities', 'Actividades de club')
        .addTag('finances', 'Control financiero')
        .build();
    const document = swagger_1.SwaggerModule.createDocument(app, config);
    swagger_1.SwaggerModule.setup('api', app, document, {
        swaggerOptions: {
            persistAuthorization: true,
            docExpansion: 'none',
            filter: true,
            showRequestDuration: true,
        },
    });
    const port = process.env.PORT || 3000;
    await app.listen(port);
    console.log(`\n🚀 Server running on: http://localhost:${port}`);
    console.log(`📖 Swagger docs on: http://localhost:${port}/api`);
    console.log(`✅ API Version: v1 (default)`);
    console.log(`📍 Base URL: http://localhost:${port}/v1`);
    console.log(`🔒 Security: Helmet, Rate Limiting, Compression enabled`);
}
bootstrap();
//# sourceMappingURL=main.js.map