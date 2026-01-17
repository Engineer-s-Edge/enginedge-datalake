import { Module, Global } from '@nestjs/common';
import { MyLogger } from './logger.service';
import { RequestContextService } from './request-context.service';
import { HttpLoggerMiddleware } from './http-logger.middleware';

@Global()
@Module({
  providers: [MyLogger, RequestContextService, HttpLoggerMiddleware],
  exports: [MyLogger, RequestContextService, HttpLoggerMiddleware],
})
export class LoggerModule {}
