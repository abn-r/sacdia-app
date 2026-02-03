import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Response, Request } from 'express';

/**
 * Filtro global de excepciones HTTP.
 * En producción oculta detalles de implementación.
 * En desarrollo muestra errores detallados.
 */
@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger('HttpException');

  catch(exception: HttpException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const status = exception.getStatus();
    const exceptionResponse = exception.getResponse();

    // Log completo internamente (no expuesto al cliente)
    this.logger.error(
      JSON.stringify({
        timestamp: new Date().toISOString(),
        method: request.method,
        url: request.url,
        status,
        message: exception.message,
        stack:
          process.env.NODE_ENV === 'development'
            ? exception.stack
            : undefined,
      }),
    );

    // En producción: errores genéricos para >= 500
    if (process.env.NODE_ENV === 'production') {
      response.status(status).json({
        status: 'error',
        statusCode: status,
        message:
          status >= HttpStatus.INTERNAL_SERVER_ERROR
            ? 'Internal server error'
            : this.extractMessage(exceptionResponse),
        timestamp: new Date().toISOString(),
        path: request.url,
      });
    } else {
      // En desarrollo: errores detallados
      response.status(status).json({
        status: 'error',
        statusCode: status,
        message: exception.message,
        details:
          typeof exceptionResponse === 'object'
            ? exceptionResponse
            : { message: exceptionResponse },
        timestamp: new Date().toISOString(),
        path: request.url,
      });
    }
  }

  private extractMessage(response: string | object): string {
    if (typeof response === 'string') {
      return response;
    }
    if (typeof response === 'object' && 'message' in response) {
      const message = (response as any).message;
      return Array.isArray(message) ? message[0] : message;
    }
    return 'An error occurred';
  }
}
