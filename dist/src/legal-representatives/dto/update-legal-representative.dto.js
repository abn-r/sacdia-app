"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.UpdateLegalRepresentativeDto = void 0;
const openapi = require("@nestjs/swagger");
const swagger_1 = require("@nestjs/swagger");
const create_legal_representative_dto_1 = require("./create-legal-representative.dto");
class UpdateLegalRepresentativeDto extends (0, swagger_1.PartialType)(create_legal_representative_dto_1.CreateLegalRepresentativeDto) {
    static _OPENAPI_METADATA_FACTORY() {
        return {};
    }
}
exports.UpdateLegalRepresentativeDto = UpdateLegalRepresentativeDto;
//# sourceMappingURL=update-legal-representative.dto.js.map