import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { KafkaLoggerService } from './infrastructure/logging/kafka-logger.service';
import { ObservabilityModule } from './observability.module';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), ObservabilityModule],
  providers: [KafkaLoggerService],
})
export class AppModule {}
