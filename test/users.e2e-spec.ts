import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { SupabaseService } from '../src/common/supabase.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { JwtAuthGuard } from '../src/common/guards/jwt-auth.guard';

describe('Users E2E Tests', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const mockSupabaseService = {
    admin: {
      auth: {
        getUser: jest.fn().mockResolvedValue({
          data: { user: { id: 'test-user-id' } },
          error: null,
        }),
      },
      storage: {
        from: jest.fn().mockReturnThis(),
        getPublicUrl: jest.fn().mockReturnValue({ data: { publicUrl: 'url' } }),
      }
    },
  };

  const mockJwtAuthGuard = {
    canActivate: jest.fn().mockReturnValue(true),
  };

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(SupabaseService)
      .useValue(mockSupabaseService)
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

  describe('/api/v1/users/:userId (GET)', () => {
    it('should return user info', async () => {
      jest.spyOn(prisma.users, 'findUnique').mockResolvedValue({
        user_id: 'test-user-id',
        email: 'test@example.com',
        name: 'Test',
        paternal_last_name: 'User',
      } as any);

      return request(app.getHttpServer())
        .get('/api/v1/users/test-user-id')
        .expect(200)
        .expect((res) => {
          expect(res.body.status).toBe('success');
          expect(res.body.data.email).toBe('test@example.com');
        });
    });
  });
});

