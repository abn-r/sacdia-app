import { PipeTransform, Injectable, ArgumentMetadata } from '@nestjs/common';
import sanitizeHtml from 'sanitize-html';

/**
 * Pipe para sanitizar inputs y prevenir XSS attacks.
 * Remueve todos los tags HTML de strings.
 */
@Injectable()
export class SanitizePipe implements PipeTransform {
  transform(value: any, metadata: ArgumentMetadata) {
    if (metadata.type !== 'body') {
      return value;
    }

    return this.sanitizeValue(value);
  }

  private sanitizeValue(value: any): any {
    if (typeof value === 'string') {
      return sanitizeHtml(value, {
        allowedTags: [],
        allowedAttributes: {},
      });
    }

    if (Array.isArray(value)) {
      return value.map((item) => this.sanitizeValue(item));
    }

    if (typeof value === 'object' && value !== null) {
      return this.sanitizeObject(value);
    }

    return value;
  }

  private sanitizeObject(obj: Record<string, any>): Record<string, any> {
    const sanitized: Record<string, any> = {};
    for (const key of Object.keys(obj)) {
      sanitized[key] = this.sanitizeValue(obj[key]);
    }
    return sanitized;
  }
}
