import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { ConfigService } from '@nestjs/config';
import { SupabaseService } from '../common/supabase.service';

describe('AuthService', () => {
  let service: AuthService;

  const mockPrismaService = {
    users: {
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    users_pr: {
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
  };

  const mockConfigService = {
    get: jest.fn().mockImplementation((key: string) => {
      const config = {
        SUPABASE_URL: 'https://test.supabase.co',
        SUPABASE_ANON_KEY: 'test-key',
        SUPABASE_SERVICE_ROLE_KEY: 'test-service-key',
      };
      return config[key];
    }),
  };

  const mockSupabaseService = {
    admin: {
      auth: {
        admin: {
          createUser: jest.fn(),
          deleteUser: jest.fn(),
          signOut: jest.fn(),
        },
        signInWithPassword: jest.fn(),
        resetPasswordForEmail: jest.fn(),
      },
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: mockPrismaService },
        { provide: ConfigService, useValue: mockConfigService },
        { provide: SupabaseService, useValue: mockSupabaseService },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
