import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  Logger,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';

/**
 * Interceptor para audit logging de todas las requests.
 * Registra información de cada request para trazabilidad.
 */
@Injectable()
export class AuditInterceptor implements NestInterceptor {
  private readonly logger = new Logger('AuditLog');

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const { method, url, ip, headers } = request;
    const user = request.user;
    const startTime = Date.now();
    const userAgent = headers['user-agent'] || 'unknown';

    return next.handle().pipe(
      tap({
        next: () => {
          const duration = Date.now() - startTime;
          this.logger.log(
            JSON.stringify({
              timestamp: new Date().toISOString(),
              userId: user?.user_id || 'anonymous',
              method,
              url: this.sanitizeUrl(url),
              ip: this.getClientIp(request),
              userAgent: userAgent.substring(0, 100),
              duration: `${duration}ms`,
              status: 'success',
            }),
          );
        },
        error: (error) => {
          const duration = Date.now() - startTime;
          this.logger.warn(
            JSON.stringify({
              timestamp: new Date().toISOString(),
              userId: user?.user_id || 'anonymous',
              method,
              url: this.sanitizeUrl(url),
              ip: this.getClientIp(request),
              userAgent: userAgent.substring(0, 100),
              duration: `${duration}ms`,
              status: 'error',
              errorMessage: error.message,
            }),
          );
        },
      }),
    );
  }

  /**
   * Obtener IP real del cliente (considerando proxies)
   */
  private getClientIp(request: any): string {
    return (
      request.headers['x-forwarded-for']?.split(',')[0]?.trim() ||
      request.headers['x-real-ip'] ||
      request.ip ||
      'unknown'
    );
  }

  /**
   * Sanitizar URL para no exponer información sensible en logs
   */
  private sanitizeUrl(url: string): string {
    // Remover query params que podrían contener tokens
    return url.split('?')[0];
  }
}
