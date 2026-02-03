import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { SupabaseService } from '../src/common/supabase.service';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Auth E2E Tests', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const mockSupabaseService = {
    admin: {
      auth: {
        admin: {
          createUser: jest.fn().mockResolvedValue({
            data: { user: { id: 'test-user-id' } },
            error: null,
          }),
          deleteUser: jest.fn().mockResolvedValue({ error: null }),
          signOut: jest.fn().mockResolvedValue({ error: null }),
        },
        signInWithPassword: jest.fn().mockResolvedValue({
          data: {
            user: { id: 'test-user-id' },
            session: { access_token: 'fake-jwt', refresh_token: 'fake-refresh' },
          },
          error: null,
        }),
      },
    },
  };

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(SupabaseService)
      .useValue(mockSupabaseService)
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

  describe('/api/v1/auth/login (POST)', () => {
    it('should login successfully', async () => {
      // Mock user in DB if necessary or rely on mocked Supabase
      // Assuming the service checks DB too
      jest.spyOn(prisma.users, 'findUnique').mockResolvedValue({
        user_id: 'test-user-id',
        email: 'test@example.com',
        users_pr: [],
      } as any);

      return request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'test@example.com', password: 'password123' })
        .expect(200)
        .expect((res) => {
          expect(res.body.status).toBe('success');
          expect(res.body.data).toHaveProperty('accessToken');
        });
    });

    it('should fail with invalid credentials', async () => {
       mockSupabaseService.admin.auth.signInWithPassword.mockResolvedValueOnce({
        data: { user: null, session: null },
        error: { message: 'Invalid login credentials' },
       });

      return request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'wrong@example.com', password: 'wrong' })
        .expect(401);
    });
  });
});
