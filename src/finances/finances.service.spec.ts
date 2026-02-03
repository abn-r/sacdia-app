import { Test, TestingModule } from '@nestjs/testing';
import { FinancesService } from './finances.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotFoundException } from '@nestjs/common';

describe('FinancesService', () => {
  let service: FinancesService;

  const mockPrismaService = {
    finances: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      count: jest.fn(),
    },
    finances_categories: {
      findMany: jest.fn(),
    },
    clubs: {
      findUnique: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FinancesService,
        { provide: PrismaService, useValue: mockPrismaService },
      ],
    }).compile();

    service = module.get<FinancesService>(FinancesService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getCategories', () => {
    it('should return active finance categories', async () => {
      const mockCategories = [
        { finance_category_id: 1, name: 'Cuotas', type: 0 },
        { finance_category_id: 2, name: 'Materiales', type: 1 },
      ];

      mockPrismaService.finances_categories.findMany.mockResolvedValue(mockCategories);

      const result = await service.getCategories();

      expect(result).toEqual(mockCategories);
    });

    it('should filter by type', async () => {
      mockPrismaService.finances_categories.findMany.mockResolvedValue([]);

      await service.getCategories(0); // Income only

      expect(mockPrismaService.finances_categories.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            type: 0,
          }),
        }),
      );
    });
  });

  describe('findByClub', () => {
    it('should return paginated finances for a club', async () => {
      const mockClub = {
        club_id: 1,
        club_adventurers: [{ club_adv_id: 1 }],
        club_pathfinders: [],
        club_master_guild: [],
      };
      const mockFinances = [
        { finance_id: 1, amount: 1000, description: 'Cuota mensual' },
      ];

      mockPrismaService.clubs.findUnique.mockResolvedValue(mockClub);
      mockPrismaService.finances.findMany.mockResolvedValue(mockFinances);
      mockPrismaService.finances.count.mockResolvedValue(1);

      const result = await service.findByClub(1);

      expect(result.data).toEqual(mockFinances);
      expect(result.meta.total).toBe(1);
    });

    it('should throw NotFoundException when club not found', async () => {
      mockPrismaService.clubs.findUnique.mockResolvedValue(null);

      await expect(service.findByClub(999)).rejects.toThrow(NotFoundException);
    });
  });

  describe('getSummary', () => {
    it('should return financial summary', async () => {
      const mockClub = {
        club_id: 1,
        club_adventurers: [{ club_adv_id: 1 }],
        club_pathfinders: [],
        club_master_guild: [],
      };

      const mockMovements = [
        { amount: 1000, finances_categories: { type: 0 } }, // income
        { amount: 500, finances_categories: { type: 0 } },  // income
        { amount: 300, finances_categories: { type: 1 } },  // expense
      ];

      mockPrismaService.clubs.findUnique.mockResolvedValue(mockClub);
      mockPrismaService.finances.findMany.mockResolvedValue(mockMovements);

      const result = await service.getSummary(1);

      expect(result.total_income).toBe(1500);
      expect(result.total_expense).toBe(300);
      expect(result.balance).toBe(1200);
    });
  });

  describe('create', () => {
    it('should create a finance record', async () => {
      const createDto = {
        year: 2026,
        month: 1,
        amount: 1000,
        club_type_id: 2,
        finance_category_id: 1,
        finance_date: '2026-01-15',
        club_pathf_id: 1,
      };

      const mockFinance = { finance_id: 1, ...createDto };
      mockPrismaService.finances.create.mockResolvedValue(mockFinance);

      const result = await service.create(createDto, 'user-123');

      expect(result).toEqual(mockFinance);
    });
  });

  describe('findOne', () => {
    it('should return finance by id', async () => {
      const mockFinance = { finance_id: 1, amount: 1000 };
      mockPrismaService.finances.findUnique.mockResolvedValue(mockFinance);

      const result = await service.findOne(1);

      expect(result).toEqual(mockFinance);
    });

    it('should throw NotFoundException when not found', async () => {
      mockPrismaService.finances.findUnique.mockResolvedValue(null);

      await expect(service.findOne(999)).rejects.toThrow(NotFoundException);
    });
  });
});
