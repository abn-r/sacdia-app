import { Test, TestingModule } from '@nestjs/testing';
import { PostRegistrationService } from './post-registration.service';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import { LegalRepresentativesService } from '../legal-representatives/legal-representatives.service';

describe('PostRegistrationService', () => {
  let service: PostRegistrationService;

  const mockPrismaService = {
    users: { findUnique: jest.fn(), update: jest.fn() },
    users_pr: { findUnique: jest.fn(), update: jest.fn(), create: jest.fn() },
    emergency_contacts: { findMany: jest.fn(), create: jest.fn() },
    legal_representatives: { findUnique: jest.fn(), create: jest.fn() },
    club_role_assignments: { create: jest.fn() },
  };

  const mockUsersService = {
    requiresLegalRepresentative: jest.fn(),
  };

  const mockLegalRepService = {
    findOne: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PostRegistrationService,
        { provide: PrismaService, useValue: mockPrismaService },
        { provide: UsersService, useValue: mockUsersService },
        { provide: LegalRepresentativesService, useValue: mockLegalRepService },
      ],
    }).compile();

    service = module.get<PostRegistrationService>(PostRegistrationService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
