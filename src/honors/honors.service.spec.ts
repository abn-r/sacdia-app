import { Test, TestingModule } from '@nestjs/testing';
import { HonorsService } from './honors.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotFoundException, ConflictException } from '@nestjs/common';

describe('HonorsService', () => {
  let service: HonorsService;

  const mockPrismaService = {
    honors: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      count: jest.fn(),
    },
    honors_categories: {
      findMany: jest.fn(),
    },
    users_honors: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      count: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        HonorsService,
        { provide: PrismaService, useValue: mockPrismaService },
      ],
    }).compile();

    service = module.get<HonorsService>(HonorsService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('findAll', () => {
    it('should return paginated honors', async () => {
      const mockHonors = [
        { honor_id: 1, name: 'Nudos', active: true },
        { honor_id: 2, name: 'Fogatas', active: true },
      ];

      mockPrismaService.honors.findMany.mockResolvedValue(mockHonors);
      mockPrismaService.honors.count.mockResolvedValue(2);

      const result = await service.findAll();

      expect(result.data).toEqual(mockHonors);
      expect(result.meta.total).toBe(2);
    });

    it('should filter by category', async () => {
      mockPrismaService.honors.findMany.mockResolvedValue([]);
      mockPrismaService.honors.count.mockResolvedValue(0);

      await service.findAll({ categoryId: 5 });

      expect(mockPrismaService.honors.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            honors_category_id: 5,
          }),
        }),
      );
    });
  });

  describe('findOne', () => {
    it('should return honor by id', async () => {
      const mockHonor = { honor_id: 1, name: 'Nudos', active: true };
      mockPrismaService.honors.findUnique.mockResolvedValue(mockHonor);

      const result = await service.findOne(1);

      expect(result).toEqual(mockHonor);
    });

    it('should throw NotFoundException when honor not found', async () => {
      mockPrismaService.honors.findUnique.mockResolvedValue(null);

      await expect(service.findOne(999)).rejects.toThrow(NotFoundException);
    });
  });

  describe('getCategories', () => {
    it('should return active categories', async () => {
      const mockCategories = [
        { honor_category_id: 1, name: 'Naturaleza' },
      ];

      mockPrismaService.honors_categories.findMany.mockResolvedValue(mockCategories);

      const result = await service.getCategories();

      expect(result).toEqual(mockCategories);
    });
  });

  describe('startHonor', () => {
    it('should create user honor', async () => {
      const mockHonor = { honor_id: 1, name: 'Nudos' };
      const mockUserHonor = {
        user_honor_id: 1,
        user_id: 'user-123',
        honor_id: 1,
        active: true,
      };

      mockPrismaService.honors.findUnique.mockResolvedValue(mockHonor);
      mockPrismaService.users_honors.findFirst.mockResolvedValue(null);
      mockPrismaService.users_honors.create.mockResolvedValue(mockUserHonor);

      const result = await service.startHonor('user-123', 1);

      expect(result).toEqual(mockUserHonor);
    });

    it('should throw ConflictException if already has honor', async () => {
      const mockHonor = { honor_id: 1, name: 'Nudos' };
      const existingUserHonor = { user_honor_id: 1, user_id: 'user-123' };

      mockPrismaService.honors.findUnique.mockResolvedValue(mockHonor);
      mockPrismaService.users_honors.findFirst.mockResolvedValue(existingUserHonor);

      await expect(service.startHonor('user-123', 1)).rejects.toThrow(ConflictException);
    });
  });

  describe('getUserHonorStats', () => {
    it('should return user honor statistics', async () => {
      mockPrismaService.users_honors.count
        .mockResolvedValueOnce(10)  // total
        .mockResolvedValueOnce(5)   // validated
        .mockResolvedValueOnce(5);  // in progress

      const result = await service.getUserHonorStats('user-123');

      expect(result).toEqual({
        total: 10,
        validated: 5,
        in_progress: 5,
      });
    });
  });
});
