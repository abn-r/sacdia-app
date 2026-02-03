import { NestFactory } from '@nestjs/core';
import { ValidationPipe, VersioningType } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import helmet from 'helmet';
import compression from 'compression';
import { json, urlencoded } from 'express';
import { AppModule } from './app.module';
import { SanitizePipe } from './common/pipes/sanitize.pipe';
import { AuditInterceptor } from './common/interceptors/audit.interceptor';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // ==========================================
  // SEGURIDAD - Helmet (Security Headers)
  // ==========================================
  const isDevelopment = process.env.NODE_ENV !== 'production';
  
  app.use(
    helmet({
      // Deshabilitar CSP en desarrollo para que Swagger UI funcione
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
    }),
  );


  // ==========================================
  // PERFORMANCE - Compression
  // ==========================================
  app.use(compression());

  // ==========================================
  // SEGURIDAD - Request Size Limits
  // ==========================================
  app.use(json({ limit: '10mb' }));
  app.use(urlencoded({ extended: true, limit: '10mb' }));

  // ==========================================
  // CORS
  // ==========================================
  const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [
    'http://localhost:5173',
    'http://localhost:3000',
  ];

  app.enableCors({
    origin: (origin, callback) => {
      // Permitir requests sin origin (e.g., Postman, curl)
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'));
      }
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    credentials: true,
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    maxAge: 3600,
  });

  // ==========================================
  // VALIDACIÓN - Global Pipes
  // ==========================================
  app.useGlobalPipes(
    new SanitizePipe(), // XSS Sanitization
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  // ==========================================
  // SEGURIDAD - Global Filters (Exception Handling)
  // ==========================================
  app.useGlobalFilters(
    new AllExceptionsFilter(), // Catch-all para errores no manejados
    new HttpExceptionFilter(), // HTTP exceptions con logs seguros
  );

  // ==========================================
  // AUDITORÍA - Global Interceptors
  // ==========================================
  app.useGlobalInterceptors(new AuditInterceptor());

  // ==========================================
  // API Versioning (URI-based)
  // ==========================================
  app.enableVersioning({
    type: VersioningType.URI,
    defaultVersion: '1',
  });


  // ==========================================
  // SWAGGER
  // ==========================================
  const config = new DocumentBuilder()
    .setTitle('SACDIA API')
    .setDescription(
      `## Sistema de Administración de Clubes de Conquistadores y Aventureros

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
`,
    )
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

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api', app, document, {
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
