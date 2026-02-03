import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';

export const ADMIN_ONLY_KEY = 'adminOnly';
export const AdminOnly = () =>
  (target: any, key?: string, descriptor?: any) => {
    Reflect.defineMetadata(ADMIN_ONLY_KEY, true, descriptor?.value ?? target);
    return descriptor ?? target;
  };

/**
 * Guard para restringir acceso a endpoints admin por IP.
 * Solo permite IPs en la whitelist configurada.
 */
@Injectable()
export class IpWhitelistGuard implements CanActivate {
  private readonly logger = new Logger(IpWhitelistGuard.name);
  private readonly allowedIps: string[];

  constructor(private reflector: Reflector) {
    // Cargar IPs permitidas desde variables de entorno
    const envIps = process.env.ADMIN_ALLOWED_IPS || '';
    this.allowedIps = envIps
      .split(',')
      .map((ip) => ip.trim())
      .filter((ip) => ip.length > 0);

    // Siempre permitir localhost en desarrollo
    if (process.env.NODE_ENV !== 'production') {
      this.allowedIps.push('127.0.0.1', '::1', 'localhost', '::ffff:127.0.0.1');
    }

    this.logger.log(`IP Whitelist configured with ${this.allowedIps.length} IPs`);
  }

  canActivate(context: ExecutionContext): boolean {
    // Verificar si el endpoint requiere validación de IP
    const isAdminOnly = this.reflector.get<boolean>(
      ADMIN_ONLY_KEY,
      context.getHandler(),
    );

    if (!isAdminOnly) {
      return true; // No requiere validación de IP
    }

    const request = context.switchToHttp().getRequest<Request>();
    const clientIp = this.getClientIp(request);

    // Verificar si la IP está en la whitelist
    const isAllowed = this.isIpAllowed(clientIp);

    if (!isAllowed) {
      this.logger.warn(
        `IP ${clientIp} denied access to admin endpoint: ${request.method} ${request.url}`,
      );
      throw new ForbiddenException(
        'Access denied. Your IP is not authorized for this operation.',
      );
    }

    this.logger.debug(`IP ${clientIp} allowed access to admin endpoint`);
    return true;
  }

  private getClientIp(request: Request): string {
    // Considerar headers de proxy
    const forwardedFor = request.headers['x-forwarded-for'];
    if (forwardedFor) {
      const ips = Array.isArray(forwardedFor)
        ? forwardedFor[0]
        : forwardedFor.split(',')[0];
      return ips.trim();
    }

    const realIp = request.headers['x-real-ip'];
    if (realIp) {
      return Array.isArray(realIp) ? realIp[0] : realIp;
    }

    return request.ip || request.socket.remoteAddress || 'unknown';
  }

  private isIpAllowed(ip: string): boolean {
    // Si no hay IPs configuradas, denegar todo en producción
    if (this.allowedIps.length === 0) {
      return process.env.NODE_ENV !== 'production';
    }

    // Normalizar IPv6-mapped IPv4
    const normalizedIp = ip.replace('::ffff:', '');

    return this.allowedIps.some((allowedIp) => {
      // Soporte para CIDR básico (ej: 192.168.1.0/24)
      if (allowedIp.includes('/')) {
        return this.isIpInCidr(normalizedIp, allowedIp);
      }
      return allowedIp === ip || allowedIp === normalizedIp;
    });
  }

  private isIpInCidr(ip: string, cidr: string): boolean {
    const [range, bits] = cidr.split('/');
    const mask = ~(2 ** (32 - parseInt(bits, 10)) - 1);
    
    const ipNum = this.ipToNumber(ip);
    const rangeNum = this.ipToNumber(range);
    
    if (ipNum === null || rangeNum === null) return false;
    
    return (ipNum & mask) === (rangeNum & mask);
  }

  private ipToNumber(ip: string): number | null {
    const parts = ip.split('.');
    if (parts.length !== 4) return null;
    
    return parts.reduce((acc, octet) => {
      const num = parseInt(octet, 10);
      if (isNaN(num) || num < 0 || num > 255) return NaN;
      return (acc << 8) + num;
    }, 0);
  }
}
