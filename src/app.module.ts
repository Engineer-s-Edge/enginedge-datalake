import { Module } from '@nestjs/common';
import { ObservabilityModule } from './observability.module';

@Module({
  imports: [ObservabilityModule],
})
export class AppModule {}
