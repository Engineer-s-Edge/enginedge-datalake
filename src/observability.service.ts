import { Injectable } from '@nestjs/common';
import axios from 'axios';
import { Client as PgClient } from 'pg';
import { Client as MinioClient } from 'minio';

interface ServiceStatus {
  status: 'healthy' | 'unhealthy';
  endpoint: string;
  lastCheck: string;
  error?: string;
}

@Injectable()
export class ObservabilityService {
  private readonly services = {
    minio: process.env.MINIO_ENDPOINT || 'http://minio:9000',
    trino: process.env.TRINO_URL || 'http://trino:8080',
    airflow: process.env.AIRFLOW_URL || 'http://airflow:8080',
    spark: process.env.SPARK_MASTER_URL || 'http://spark-master:8080',
    postgres: process.env.POSTGRES_URL || 'postgres:5432',
    marquez: process.env.MARQUEZ_API_URL || 'http://marquez-api:5000',
  };

  private readonly minioClient = new MinioClient({
    endPoint: 'minio',
    port: 9000,
    useSSL: false,
    accessKey: process.env.MINIO_ROOT_USER || 'minioadmin',
    secretKey: process.env.MINIO_ROOT_PASSWORD || 'minioadmin123',
  });

  async checkServices(): Promise<Record<string, ServiceStatus>> {
    const serviceChecks = await Promise.all([
      this.checkHttpService('minio', `${this.services.minio}/minio/health/live`),
      this.checkHttpService('trino', `${this.services.trino}/v1/info`),
      this.checkHttpService('airflow', `${this.services.airflow}/health`),
      this.checkSpark(),
      this.checkPostgres(),
      this.checkHttpService('marquez', `${this.services.marquez}/healthcheck`),
    ]);

    return serviceChecks.reduce((acc, check) => {
      acc[check.name] = check.status;
      return acc;
    }, {});
  }

  async getBucketCount(): Promise<number> {
    try {
      const buckets = await this.minioClient.listBuckets();
      return buckets.length;
    } catch (error) {
      return 0;
    }
  }

  async getActiveQueryCount(): Promise<number> {
    try {
      const response = await axios.get(`${this.services.trino}/v1/query`, { timeout: 5000 });
      const queries = response.data;
      const runningQueries = queries.filter((q) => q.state === 'RUNNING');
      return runningQueries.length;
    } catch (error) {
      return 0;
    }
  }

  private async checkHttpService(name: string, endpoint: string): Promise<{ name: string; status: ServiceStatus }> {
    const status: ServiceStatus = {
      endpoint,
      lastCheck: new Date().toISOString(),
      status: 'unhealthy',
    };

    try {
      const response = await axios.get(endpoint, { timeout: 5000 });
      if (response.status >= 200 && response.status < 300) {
        status.status = 'healthy';
      } else {
        status.error = `Received status code ${response.status}`;
      }
    } catch (error) {
      status.error = error.message;
    }

    return { name, status };
  }

  private async checkSpark(): Promise<{ name: string; status: ServiceStatus }> {
    const endpoint = this.services.spark;
    const status: ServiceStatus = {
      endpoint,
      lastCheck: new Date().toISOString(),
      status: 'unhealthy',
    };

    try {
      const response = await axios.get(endpoint, { timeout: 5000 });
      if (response.status >= 200 && response.status < 300) {
        // A more robust check for spark would be to check for active workers.
        if (response.data.includes('Alive Workers')) {
            status.status = 'healthy';
        } else {
            status.error = 'Spark master UI is up, but no alive workers found.';
        }
      } else {
        status.error = `Received status code ${response.status}`;
      }
    } catch (error) {
      status.error = error.message;
    }

    return { name: 'spark', status };
  }

  private async checkPostgres(): Promise<{ name: string; status: ServiceStatus }> {
    const endpoint = this.services.postgres;
    const status: ServiceStatus = {
      endpoint,
      lastCheck: new Date().toISOString(),
      status: 'unhealthy',
    };

    const client = new PgClient({
        host: 'postgres',
        port: 5432,
        user: process.env.POSTGRES_USER || 'airflow',
        password: process.env.POSTGRES_PASSWORD || 'airflow',
        database: process.env.POSTGRES_DB || 'airflow',
        connectionTimeoutMillis: 5000,
    });

    try {
      await client.connect();
      status.status = 'healthy';
    } catch (error) {
      status.error = error.message;
    } finally {
      await client.end();
    }

    return { name: 'postgres', status };
  }
}
