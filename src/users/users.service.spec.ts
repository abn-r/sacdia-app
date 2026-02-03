import { Test, TestingModule } from '@nestjs/testing';
import { UsersService } from './users.service';
import { PrismaService } from '../prisma/prisma.service';
import { SupabaseService } from '../common/supabase.service';

describe('UsersService', () => {
  let service: UsersService;

  const mockPrismaService = {
    users: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
  };

  const mockSupabaseService = {
    admin: {
      storage: {
        from: jest.fn().mockReturnThis(),
        upload: jest.fn().mockResolvedValue({ error: null }),
        getPublicUrl: jest.fn().mockReturnValue({ data: { publicUrl: 'url' } }),
        remove: jest.fn().mockResolvedValue({ error: null }),
      },
      auth: {
        admin: {
          createUser: jest.fn(),
          deleteUser: jest.fn(),
        },
      },
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: PrismaService, useValue: mockPrismaService },
        { provide: SupabaseService, useValue: mockSupabaseService },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
