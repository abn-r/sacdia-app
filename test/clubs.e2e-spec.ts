import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { JwtAuthGuard } from '../src/common/guards/jwt-auth.guard';

describe('Clubs E2E Tests', () => {
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

  describe('/api/v1/clubs (GET)', () => {
    it('should return paginated list of clubs', async () => {
      jest.spyOn(prisma.clubs, 'findMany').mockResolvedValue([]);
      jest.spyOn(prisma.clubs, 'count').mockResolvedValue(0);

      const response = await request(app.getHttpServer())
        .get('/api/v1/clubs')
        .expect(200);

      expect(response.body).toHaveProperty('data');
      expect(response.body).toHaveProperty('meta');
    });
  });

  describe('/api/v1/clubs (POST)', () => {
    it('should create a new club', async () => {
      const mockClub = {
        club_id: 1,
        name: 'Test Club',
        district_id: 1,
        active: true,
      };

      jest.spyOn(prisma.clubs, 'create').mockResolvedValue(mockClub as any);
      // Spy on nested instance creation if necessary for service logic
      // Assuming service simple create:
      
      return request(app.getHttpServer())
        .post('/api/v1/clubs')
        .send({
          name: 'Test Club',
          local_field_id: 1,
          districlub_type_id: 1,
          church_id: 1,
        })
        .expect(201);
    });
  });
});
