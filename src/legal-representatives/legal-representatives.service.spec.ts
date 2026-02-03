import { Test, TestingModule } from '@nestjs/testing';
import { LegalRepresentativesService } from './legal-representatives.service';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';

describe('LegalRepresentativesService', () => {
  let service: LegalRepresentativesService;

  const mockPrismaService = {
    legal_representatives: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
  };

  const mockUsersService = {
    requiresLegalRepresentative: jest.fn(),
    findOne: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        LegalRepresentativesService,
        { provide: PrismaService, useValue: mockPrismaService },
        { provide: UsersService, useValue: mockUsersService },
      ],
    }).compile();

    service = module.get<LegalRepresentativesService>(LegalRepresentativesService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
