import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Response, Request } from 'express';

/**
 * Filtro para excepciones no manejadas (errores inesperados).
 * Captura cualquier error que no sea HttpException.
 * Siempre retorna 500 con mensaje genérico en producción.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('UnhandledException');

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const errorMessage =
      exception instanceof Error ? exception.message : 'Unknown error';
    const errorStack =
      exception instanceof Error ? exception.stack : undefined;

    // Log completo internamente
    this.logger.error(
      JSON.stringify({
        timestamp: new Date().toISOString(),
        method: request.method,
        url: request.url,
        message: errorMessage,
        stack:
          process.env.NODE_ENV === 'development' ? errorStack : undefined,
      }),
    );

    // Siempre retornar error genérico al cliente
    response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      status: 'error',
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      message:
        process.env.NODE_ENV === 'production'
          ? 'Internal server error'
          : errorMessage,
      timestamp: new Date().toISOString(),
      path: request.url,
    });
  }
}
