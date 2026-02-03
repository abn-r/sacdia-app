import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Catalogs E2E Tests', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    app.setGlobalPrefix('api/v1');
    
    prisma = app.get(PrismaService);
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('/api/v1/catalogs/club-types (GET)', () => {
    it('should return list of club types', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalogs/club-types')
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
      if (response.body.length > 0) {
        expect(response.body[0]).toHaveProperty('club_type_id');
        expect(response.body[0]).toHaveProperty('name');
      }
    });
  });

  describe('/api/v1/catalogs/countries (GET)', () => {
    it('should return list of countries', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalogs/countries')
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
    });
  });

  describe('/api/v1/catalogs/unions (GET)', () => {
    it('should return list of unions', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalogs/unions')
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
    });

    it('should filter unions by country', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalogs/unions?countryId=1')
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
    });
  });

  describe('/api/v1/catalogs/roles (GET)', () => {
    it('should return list of roles', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalogs/roles')
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
    });

    it('should filter roles by category', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalogs/roles?category=CLUB')
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
    });
  });

  describe('/api/v1/catalogs/ecclesiastical-years (GET)', () => {
    it('should return list of ecclesiastical years', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalogs/ecclesiastical-years')
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
    });
  });

  describe('/api/v1/catalogs/ecclesiastical-years/current (GET)', () => {
    it('should return current ecclesiastical year', async () => {
      const mockYear = {
        year_id: 1,
        start_date: new Date(),
        end_date: new Date(),
        active: true,
        created_at: new Date(),
        modified_at: new Date(),
      };

      // Spy on Prisma to avoid failure if DB has no active year for today
      jest.spyOn(prisma.ecclesiastical_years, 'findFirst').mockResolvedValue(mockYear);

      const response = await request(app.getHttpServer())
        .get('/api/v1/catalogs/ecclesiastical-years/current')
        .expect(200);

      expect(response.body).toHaveProperty('year_id');
      expect(response.body).toHaveProperty('active', true);
    });
  });
});
