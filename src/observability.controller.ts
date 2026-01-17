import { Controller, Get } from '@nestjs/common';
import { ObservabilityService } from './observability.service';

@Controller('observability')
export class ObservabilityController {
  constructor(private readonly observabilityService: ObservabilityService) {}

  @Get('health')
  async getHealth() {
    const services = await this.observabilityService.checkServices();
    const allHealthy = Object.values(services).every((s) => s.status === 'healthy');

    return {
      status: allHealthy ? 'healthy' : 'degraded',
      timestamp: new Date().toISOString(),
      services,
    };
  }

  @Get('metrics')
  async getMetrics() {
    const services = await this.observabilityService.checkServices();
    const servicesUp = Object.values(services).filter((s) => s.status === 'healthy').length;
    const bucketCount = await this.observabilityService.getBucketCount();
    const activeQueryCount = await this.observabilityService.getActiveQueryCount();

    return {
      datalake_services_up: servicesUp,
      datalake_storage_buckets: bucketCount,
      datalake_active_queries: activeQueryCount,
      timestamp: new Date().toISOString(),
    };
  }
}
