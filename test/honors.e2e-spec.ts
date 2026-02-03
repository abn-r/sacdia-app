import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Honors E2E Tests', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    app.setGlobalPrefix('api/v1');
    
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('/api/v1/honors (GET)', () => {
    it('should return paginated list of honors', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/honors')
        .expect(200);

      expect(response.body).toHaveProperty('data');
      expect(response.body).toHaveProperty('meta');
      expect(Array.isArray(response.body.data)).toBe(true);
      expect(response.body.meta).toHaveProperty('page');
      expect(response.body.meta).toHaveProperty('limit');
      expect(response.body.meta).toHaveProperty('total');
    });

    it('should support pagination', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/honors?page=1&limit=10')
        .expect(200);

      expect(response.body.meta.page).toBe(1);
      expect(response.body.meta.limit).toBe(10);
    });

    it('should filter by category', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/honors?categoryId=1')
        .expect(200);

      expect(response.body).toHaveProperty('data');
    });

    it('should filter by club type', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/honors?clubTypeId=2')
        .expect(200);

      expect(response.body).toHaveProperty('data');
    });
  });

  describe('/api/v1/honors/categories (GET)', () => {
    it('should return list of honor categories', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/honors/categories')
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
      if (response.body.length > 0) {
        expect(response.body[0]).toHaveProperty('honor_category_id');
        expect(response.body[0]).toHaveProperty('name');
      }
    });
  });

  describe('/api/v1/honors/:honorId (GET)', () => {
    it('should return 404 for non-existent honor', async () => {
      await request(app.getHttpServer())
        .get('/api/v1/honors/999999')
        .expect(404);
    });
  });
});
