import { Test, TestingModule } from '@nestjs/testing';
import { PostRegistrationController } from './post-registration.controller';
import { PostRegistrationService } from './post-registration.service';

describe('PostRegistrationController', () => {
  let controller: PostRegistrationController;

  const mockPostRegistrationService = {
    getStatus: jest.fn(),
    updatePersonalInfo: jest.fn(),
    updateProfilePicture: jest.fn(),
    selectClub: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [PostRegistrationController],
      providers: [
        { provide: PostRegistrationService, useValue: mockPostRegistrationService },
      ],
    }).compile();

    controller = module.get<PostRegistrationController>(PostRegistrationController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
