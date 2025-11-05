import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { KafkaLoggerService } from './infrastructure/logging/kafka-logger.service';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useLogger(app.get(KafkaLoggerService));
  app.setGlobalPrefix('api');
  const port = process.env.PORT || 3010;
  await app.listen(port);
  console.log(`Datalake Observability API running on port ${port}`);
}
bootstrap();
