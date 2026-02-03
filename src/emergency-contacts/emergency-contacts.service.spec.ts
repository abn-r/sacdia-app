import { Test, TestingModule } from '@nestjs/testing';
import { EmergencyContactsService } from './emergency-contacts.service';
import { PrismaService } from '../prisma/prisma.service';

describe('EmergencyContactsService', () => {
  let service: EmergencyContactsService;

  const mockPrismaService = {
    emergency_contacts: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
      count: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        EmergencyContactsService,
        { provide: PrismaService, useValue: mockPrismaService },
      ],
    }).compile();

    service = module.get<EmergencyContactsService>(EmergencyContactsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
