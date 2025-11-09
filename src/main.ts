import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { MyLogger } from './infrastructure/logging/logger.service';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true,
  });
  
  const logger = await app.resolve(MyLogger);
  app.useLogger(logger);
  
  app.setGlobalPrefix('api');
  const port = process.env.PORT || 3010;
  await app.listen(port);
  logger.info(`Datalake Observability API running on port ${port}`, 'Bootstrap');
}
bootstrap();
