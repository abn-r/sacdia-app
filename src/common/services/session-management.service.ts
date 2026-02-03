import { Injectable, Logger, Inject } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import type { Cache } from 'cache-manager';

export interface UserSession {
  sessionId: string;
  userId: string;
  deviceInfo: string;
  ipAddress: string;
  createdAt: Date;
  lastActivity: Date;
}

/**
 * Servicio para manejar límites de sesiones concurrentes por usuario.
 * Permite máximo N sesiones activas simultáneamente.
 */
@Injectable()
export class SessionManagementService {
  private readonly logger = new Logger(SessionManagementService.name);
  private readonly SESSION_PREFIX = 'session:';
  private readonly MAX_SESSIONS = 5; // Máximo de sesiones por usuario
  private readonly SESSION_TTL = 86400; // 24 horas

  constructor(@Inject(CACHE_MANAGER) private cacheManager: Cache) {}

  /**
   * Registrar una nueva sesión para un usuario.
   * Si excede el límite, elimina la sesión más antigua.
   */
  async createSession(
    userId: string,
    sessionId: string,
    deviceInfo: string,
    ipAddress: string,
  ): Promise<{ created: boolean; removedSession?: string }> {
    const sessions = await this.getUserSessions(userId);
    let removedSession: string | undefined;

    // Si excede el límite, eliminar la sesión más antigua
    if (sessions.length >= this.MAX_SESSIONS) {
      const oldestSession = sessions.sort(
        (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
      )[0];
      
      await this.removeSession(userId, oldestSession.sessionId);
      removedSession = oldestSession.sessionId;
      this.logger.warn(
        `Session limit reached for user ${userId}. Removed oldest session.`,
      );
    }

    // Crear nueva sesión
    const session: UserSession = {
      sessionId,
      userId,
      deviceInfo,
      ipAddress,
      createdAt: new Date(),
      lastActivity: new Date(),
    };

    const key = this.getSessionKey(userId, sessionId);
    await this.cacheManager.set(key, JSON.stringify(session), this.SESSION_TTL * 1000);

    // Añadir a la lista de sesiones del usuario
    await this.addToUserSessionList(userId, sessionId);

    this.logger.log(`New session created for user ${userId}: ${sessionId}`);

    return { created: true, removedSession };
  }

  /**
   * Obtener todas las sesiones activas de un usuario.
   */
  async getUserSessions(userId: string): Promise<UserSession[]> {
    const sessionIds = await this.getUserSessionIds(userId);
    const sessions: UserSession[] = [];

    for (const sessionId of sessionIds) {
      const key = this.getSessionKey(userId, sessionId);
      const sessionData = await this.cacheManager.get<string>(key);
      
      if (sessionData) {
        sessions.push(JSON.parse(sessionData));
      }
    }

    return sessions;
  }

  /**
   * Actualizar última actividad de una sesión.
   */
  async updateSessionActivity(userId: string, sessionId: string): Promise<void> {
    const key = this.getSessionKey(userId, sessionId);
    const sessionData = await this.cacheManager.get<string>(key);
    
    if (sessionData) {
      const session = JSON.parse(sessionData) as UserSession;
      session.lastActivity = new Date();
      await this.cacheManager.set(key, JSON.stringify(session), this.SESSION_TTL * 1000);
    }
  }

  /**
   * Verificar si una sesión es válida.
   */
  async isValidSession(userId: string, sessionId: string): Promise<boolean> {
    const key = this.getSessionKey(userId, sessionId);
    const session = await this.cacheManager.get<string>(key);
    return session !== null && session !== undefined;
  }

  /**
   * Eliminar una sesión específica.
   */
  async removeSession(userId: string, sessionId: string): Promise<void> {
    const key = this.getSessionKey(userId, sessionId);
    await this.cacheManager.del(key);
    await this.removeFromUserSessionList(userId, sessionId);
    this.logger.log(`Session removed: ${sessionId} for user ${userId}`);
  }

  /**
   * Cerrar todas las sesiones de un usuario (logout de todos los dispositivos).
   */
  async removeAllSessions(userId: string): Promise<number> {
    const sessionIds = await this.getUserSessionIds(userId);
    
    for (const sessionId of sessionIds) {
      const key = this.getSessionKey(userId, sessionId);
      await this.cacheManager.del(key);
    }

    // Limpiar lista de sesiones
    await this.cacheManager.del(this.getUserSessionListKey(userId));

    this.logger.warn(`All ${sessionIds.length} sessions removed for user ${userId}`);
    return sessionIds.length;
  }

  /**
   * Obtener estadísticas de sesiones de un usuario.
   */
  async getSessionStats(userId: string): Promise<{
    activeSessions: number;
    maxSessions: number;
    sessions: UserSession[];
  }> {
    const sessions = await this.getUserSessions(userId);
    return {
      activeSessions: sessions.length,
      maxSessions: this.MAX_SESSIONS,
      sessions,
    };
  }

  // ==========================================
  // HELPERS PRIVADOS
  // ==========================================

  private getSessionKey(userId: string, sessionId: string): string {
    return `${this.SESSION_PREFIX}${userId}:${sessionId}`;
  }

  private getUserSessionListKey(userId: string): string {
    return `${this.SESSION_PREFIX}list:${userId}`;
  }

  private async getUserSessionIds(userId: string): Promise<string[]> {
    const key = this.getUserSessionListKey(userId);
    const data = await this.cacheManager.get<string>(key);
    return data ? JSON.parse(data) : [];
  }

  private async addToUserSessionList(
    userId: string,
    sessionId: string,
  ): Promise<void> {
    const sessionIds = await this.getUserSessionIds(userId);
    if (!sessionIds.includes(sessionId)) {
      sessionIds.push(sessionId);
      const key = this.getUserSessionListKey(userId);
      await this.cacheManager.set(key, JSON.stringify(sessionIds), this.SESSION_TTL * 1000);
    }
  }

  private async removeFromUserSessionList(
    userId: string,
    sessionId: string,
  ): Promise<void> {
    const sessionIds = await this.getUserSessionIds(userId);
    const filtered = sessionIds.filter((id) => id !== sessionId);
    const key = this.getUserSessionListKey(userId);
    await this.cacheManager.set(key, JSON.stringify(filtered), this.SESSION_TTL * 1000);
  }
}
