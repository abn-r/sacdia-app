import { CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
export declare const ADMIN_ONLY_KEY = "adminOnly";
export declare const AdminOnly: () => (target: any, key?: string, descriptor?: any) => any;
export declare class IpWhitelistGuard implements CanActivate {
    private reflector;
    private readonly logger;
    private readonly allowedIps;
    constructor(reflector: Reflector);
    canActivate(context: ExecutionContext): boolean;
    private getClientIp;
    private isIpAllowed;
    private isIpInCidr;
    private ipToNumber;
}
