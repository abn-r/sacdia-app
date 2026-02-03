"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const core_1 = require("@nestjs/core");
const swagger_1 = require("@nestjs/swagger");
const app_module_1 = require("../src/app.module");
const fs = __importStar(require("fs"));
const common_1 = require("@nestjs/common");
async function generateSwagger() {
    const app = await core_1.NestFactory.create(app_module_1.AppModule, { logger: false });
    app.enableVersioning({
        type: common_1.VersioningType.URI,
        defaultVersion: '1',
    });
    const config = new swagger_1.DocumentBuilder()
        .setTitle('SACDIA API')
        .setDescription(`## Sistema de Administración de Clubes de Conquistadores y Aventureros\n\n### Módulos Disponibles\n- **Auth**: Autenticación con Supabase + JWT\n- **Users**: Gestión de perfiles de usuario\n- **Catalogs**: Catálogos de referencia\n- **Clubs**: Gestión de clubes e instancias\n- **Classes**: Clases progresivas\n- **Honors**: Especialidades\n- **Activities**: Actividades de club\n- **Finances**: Control financiero`)
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
    const document = swagger_1.SwaggerModule.createDocument(app, config);
    fs.writeFileSync('./sacdia-api-spec.json', JSON.stringify(document, null, 2));
    console.log('✅ OpenAPI spec generated at ./sacdia-api-spec.json');
    await app.close();
    process.exit(0);
}
generateSwagger();
//# sourceMappingURL=generate-openapi.js.map