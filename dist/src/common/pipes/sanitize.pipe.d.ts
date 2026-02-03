import { PipeTransform, ArgumentMetadata } from '@nestjs/common';
export declare class SanitizePipe implements PipeTransform {
    transform(value: any, metadata: ArgumentMetadata): any;
    private sanitizeValue;
    private sanitizeObject;
}
