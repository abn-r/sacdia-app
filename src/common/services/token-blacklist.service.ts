import { Injectable, Logger, Inject } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import type { Cache } from 'cache-manager';

/**
 * Servicio para manejar blacklist de tokens JWT.
 * Almacena tokens revocados hasta que expiren.
 */
@Injectable()
export class TokenBlacklistService {
  private readonly logger = new Logger(TokenBlacklistService.name);
  private readonly BLACKLIST_PREFIX = 'token:blacklist:';

  constructor(@Inject(CACHE_MANAGER) private cacheManager: Cache) {}

  /**
   * Añadir un token a la blacklist.
   * @param token - Token JWT a revocar
   * @param expiresInSeconds - Tiempo hasta que el token expire
   */
  async blacklistToken(token: string, expiresInSeconds: number): Promise<void> {
    const key = this.getBlacklistKey(token);
    await this.cacheManager.set(key, 'revoked', expiresInSeconds * 1000);
    this.logger.log(`Token blacklisted, expires in ${expiresInSeconds}s`);
  }

  /**
   * Verificar si un token está en la blacklist.
   * @param token - Token JWT a verificar
   * @returns true si el token está revocado
   */
  async isBlacklisted(token: string): Promise<boolean> {
    const key = this.getBlacklistKey(token);
    const result = await this.cacheManager.get<string>(key);
    return result === 'revoked';
  }

  /**
   * Revocar todos los tokens de un usuario.
   * Útil para logout de todas las sesiones.
   * @param userId - ID del usuario
   * @param expiresInSeconds - TTL del registro
   */
  async blacklistAllUserTokens(
    userId: string,
    expiresInSeconds: number = 86400,
  ): Promise<void> {
    const key = `${this.BLACKLIST_PREFIX}user:${userId}:all`;
    await this.cacheManager.set(key, Date.now().toString(), expiresInSeconds * 1000);
    this.logger.warn(`All tokens blacklisted for user ${userId}`);
  }

  /**
   * Verificar si todos los tokens de un usuario están bloqueados.
   * @param userId - ID del usuario
   * @param tokenIssuedAt - Timestamp de emisión del token
   * @returns true si el token fue emitido antes del bloqueo
   */
  async isUserBlacklisted(userId: string, tokenIssuedAt: number): Promise<boolean> {
    const key = `${this.BLACKLIST_PREFIX}user:${userId}:all`;
    const blacklistTime = await this.cacheManager.get<string>(key);
    
    if (!blacklistTime) return false;
    
    // Si el token fue emitido antes del bloqueo, está revocado
    return tokenIssuedAt < parseInt(blacklistTime, 10);
  }

  private getBlacklistKey(token: string): string {
    // Usar hash corto del token para la key
    const hash = this.hashToken(token);
    return `${this.BLACKLIST_PREFIX}${hash}`;
  }

  private hashToken(token: string): string {
    // Usar últimos 32 caracteres del token como identificador
    return token.slice(-32);
  }
}
