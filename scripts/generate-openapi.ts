import { NestFactory } from '@nestjs/core';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from '../src/app.module';
import * as fs from 'fs';
import { VersioningType } from '@nestjs/common';

async function generateSwagger() {
  const app = await NestFactory.create(AppModule, { logger: false });

  // Configuración idéntica a main.ts para que el spec sea igual
  app.enableVersioning({
    type: VersioningType.URI,
    defaultVersion: '1',
  });

  const config = new DocumentBuilder()
    .setTitle('SACDIA API')
    .setDescription(
      `## Sistema de Administración de Clubes de Conquistadores y Aventureros\n\n### Módulos Disponibles\n- **Auth**: Autenticación con Supabase + JWT\n- **Users**: Gestión de perfiles de usuario\n- **Catalogs**: Catálogos de referencia\n- **Clubs**: Gestión de clubes e instancias\n- **Classes**: Clases progresivas\n- **Honors**: Especialidades\n- **Activities**: Actividades de club\n- **Finances**: Control financiero`,
    )
    .setVersion('2.2.0')
    .setContact('SACDIA Team', 'https://sacdia.app', 'dev@sacdia.app')
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

  // Escribir a archivo
  fs.writeFileSync('./sacdia-api-spec.json', JSON.stringify(document, null, 2));
  console.log('✅ OpenAPI spec generated at ./sacdia-api-spec.json');

  await app.close();
  process.exit(0);
}

generateSwagger();
