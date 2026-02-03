import { Test, TestingModule } from '@nestjs/testing';
import { CatalogsService } from './catalogs.service';
import { PrismaService } from '../prisma/prisma.service';

describe('CatalogsService', () => {
  let service: CatalogsService;
  let prisma: PrismaService;

  const mockPrismaService = {
    club_types: {
      findMany: jest.fn(),
    },
    countries: {
      findMany: jest.fn(),
    },
    unions: {
      findMany: jest.fn(),
    },
    local_fields: {
      findMany: jest.fn(),
    },
    districts: {
      findMany: jest.fn(),
    },
    churches: {
      findMany: jest.fn(),
    },
    roles: {
      findMany: jest.fn(),
    },
    ecclesiastical_years: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
    },
    club_ideals: {
      findMany: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CatalogsService,
        { provide: PrismaService, useValue: mockPrismaService },
      ],
    }).compile();

    service = module.get<CatalogsService>(CatalogsService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getClubTypes', () => {
    it('should return active club types', async () => {
      const mockClubTypes = [
        { club_type_id: 1, name: 'Aventureros', active: true },
        { club_type_id: 2, name: 'Conquistadores', active: true },
        { club_type_id: 3, name: 'Guías Mayores', active: true },
      ];

      mockPrismaService.club_types.findMany.mockResolvedValue(mockClubTypes);

      const result = await service.getClubTypes();

      expect(result).toEqual(mockClubTypes);
      expect(mockPrismaService.club_types.findMany).toHaveBeenCalledWith({
        where: { active: true },
        select: {
          club_type_id: true,
          name: true,
        },
        orderBy: { name: 'asc' },
      });
    });
  });

  describe('getCountries', () => {
    it('should return active countries', async () => {
      const mockCountries = [
        { country_id: 1, name: 'México', active: true },
      ];

      mockPrismaService.countries.findMany.mockResolvedValue(mockCountries);

      const result = await service.getCountries();

      expect(result).toEqual(mockCountries);
      expect(mockPrismaService.countries.findMany).toHaveBeenCalled();
    });
  });

  describe('getUnions', () => {
    it('should return unions filtered by country', async () => {
      const mockUnions = [
        { union_id: 1, name: 'Unión Mexicana del Norte', country_id: 1 },
      ];

      mockPrismaService.unions.findMany.mockResolvedValue(mockUnions);

      const result = await service.getUnions(1);

      expect(result).toEqual(mockUnions);
      expect(mockPrismaService.unions.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            country_id: 1,
          }),
        }),
      );
    });

    it('should return all unions when no filter', async () => {
      const mockUnions = [
        { union_id: 1, name: 'Unión 1' },
        { union_id: 2, name: 'Unión 2' },
      ];

      mockPrismaService.unions.findMany.mockResolvedValue(mockUnions);

      const result = await service.getUnions();

      expect(result).toEqual(mockUnions);
    });
  });

  describe('getRoles', () => {
    it('should return roles filtered by category', async () => {
      const mockRoles = [
        { role_id: '1', role_name: 'director', role_category: 'CLUB' },
      ];

      mockPrismaService.roles.findMany.mockResolvedValue(mockRoles);

      const result = await service.getRoles('CLUB');

      expect(result).toEqual(mockRoles);
      expect(mockPrismaService.roles.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            role_category: 'CLUB',
          }),
        }),
      );
    });
  });

  describe('getCurrentEcclesiasticalYear', () => {
    it('should return active ecclesiastical year', async () => {
      const mockYear = {
        year_id: 1,
        start_date: new Date('2025-08-01'),
        end_date: new Date('2026-07-31'),
        active: true,
      };

      mockPrismaService.ecclesiastical_years.findFirst.mockResolvedValue(mockYear);

      const result = await service.getCurrentEcclesiasticalYear();

      expect(result).toEqual(mockYear);
      expect(mockPrismaService.ecclesiastical_years.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            start_date: expect.any(Object),
            end_date: expect.any(Object),
          }),
        }),
      );
    });
  });
});
