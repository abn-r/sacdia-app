import { Test, TestingModule } from '@nestjs/testing';
import { ActivitiesService } from './activities.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotFoundException } from '@nestjs/common';

describe('ActivitiesService', () => {
  let service: ActivitiesService;

  const mockPrismaService = {
    activities: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      count: jest.fn(),
    },
    clubs: {
      findUnique: jest.fn(),
    },
    users: {
      findMany: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ActivitiesService,
        { provide: PrismaService, useValue: mockPrismaService },
      ],
    }).compile();

    service = module.get<ActivitiesService>(ActivitiesService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('findByClub', () => {
    it('should return paginated activities for a club', async () => {
      const mockClub = {
        club_id: 1,
        club_adventurers: [{ club_adv_id: 1 }],
        club_pathfinders: [{ club_pathf_id: 1 }],
        club_master_guild: [],
      };
      const mockActivities = [
        { activity_id: 1, name: 'Campamento', active: true },
      ];

      mockPrismaService.clubs.findUnique.mockResolvedValue(mockClub);
      mockPrismaService.activities.findMany.mockResolvedValue(mockActivities);
      mockPrismaService.activities.count.mockResolvedValue(1);

      const result = await service.findByClub(1);

      expect(result.data).toEqual(mockActivities);
      expect(result.meta.total).toBe(1);
    });

    it('should throw NotFoundException when club not found', async () => {
      mockPrismaService.clubs.findUnique.mockResolvedValue(null);

      await expect(service.findByClub(999)).rejects.toThrow(NotFoundException);
    });
  });

  describe('findOne', () => {
    it('should return activity by id', async () => {
      const mockActivity = { activity_id: 1, name: 'Campamento' };
      mockPrismaService.activities.findUnique.mockResolvedValue(mockActivity);

      const result = await service.findOne(1);

      expect(result).toEqual(mockActivity);
    });

    it('should throw NotFoundException when not found', async () => {
      mockPrismaService.activities.findUnique.mockResolvedValue(null);

      await expect(service.findOne(999)).rejects.toThrow(NotFoundException);
    });
  });

  describe('create', () => {
    it('should create an activity', async () => {
      const createDto = {
        name: 'Campamento',
        club_type_id: 2,
        lat: 19.4326,
        long: -99.1332,
        activity_place: 'Parque Nacional',
        image: 'https://example.com/image.jpg',
        club_adv_id: 1,
        club_pathf_id: 1,
        club_mg_id: 1,
      };

      const mockActivity = { activity_id: 1, ...createDto };
      mockPrismaService.activities.create.mockResolvedValue(mockActivity);

      const result = await service.create(createDto, 'user-123');

      expect(result).toEqual(mockActivity);
    });
  });

  describe('recordAttendance', () => {
    it('should record attendance for an activity', async () => {
      const mockActivity = { activity_id: 1, name: 'Campamento' };
      const attendees = ['user-1', 'user-2', 'user-3'];

      mockPrismaService.activities.findUnique.mockResolvedValue(mockActivity);
      mockPrismaService.activities.update.mockResolvedValue({
        ...mockActivity,
        attendees,
      });

      const result = await service.recordAttendance(1, { user_ids: attendees });

      expect(result.attendees).toEqual(attendees);
    });
  });

  describe('getAttendance', () => {
    it('should return attendance list', async () => {
      const mockActivity = {
        activity_id: 1,
        name: 'Campamento',
        attendees: ['user-1', 'user-2'],
      };
      const mockUsers = [
        { user_id: 'user-1', name: 'Juan' },
        { user_id: 'user-2', name: 'María' },
      ];

      mockPrismaService.activities.findUnique.mockResolvedValue(mockActivity);
      mockPrismaService.users.findMany.mockResolvedValue(mockUsers);

      const result = await service.getAttendance(1);

      expect(result.total_attendees).toBe(2);
      expect(result.attendees).toEqual(mockUsers);
    });
  });
});
