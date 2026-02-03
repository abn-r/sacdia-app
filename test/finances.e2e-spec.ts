import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { JwtAuthGuard } from '../src/common/guards/jwt-auth.guard';

describe('Finances E2E Tests', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const mockJwtAuthGuard = {
    canActivate: jest.fn().mockReturnValue(true),
  };

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue(mockJwtAuthGuard)
      .compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    app.setGlobalPrefix('api/v1');

    prisma = app.get(PrismaService);
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('/api/v1/clubs/:clubId/finances (GET)', () => {
    it('should return paginated list of finances', async () => {
      jest.spyOn(prisma.clubs, 'findUnique').mockResolvedValue({
        club_id: 1,
        club_adventurers: [],
        club_pathfinders: [],
        club_master_guild: [],
      } as any);

      jest.spyOn(prisma.finances, 'findMany').mockResolvedValue([]);
      jest.spyOn(prisma.finances, 'count').mockResolvedValue(0);

      const response = await request(app.getHttpServer())
        .get('/api/v1/clubs/1/finances')
        .expect(200);

      expect(response.body).toHaveProperty('data');
    });
  });

  describe('/api/v1/finances/categories (GET)', () => {
    it('should return list of categories', async () => {
      // Corrected property name to match service usage (plural)
      jest.spyOn(prisma.finances_categories, 'findMany').mockResolvedValue([]);
      
      const response = await request(app.getHttpServer())
        .get('/api/v1/finances/categories')
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
    });
  });
});
