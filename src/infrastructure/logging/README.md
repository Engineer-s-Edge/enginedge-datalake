# Logging Infrastructure

This directory contains the logging infrastructure for the EnginEdge Datalake service, implementing a comprehensive Winston-based logging solution.

## Components

### MyLogger Service (`logger.service.ts`)
The main logging service that provides:
- **Winston integration** with pretty console output and JSON file logging
- **Request tracking** via request ID propagation
- **Automatic call site detection** showing source file/line numbers
- **Sensitive data redaction** (passwords, tokens, API keys, etc.)
- **Log rotation** with daily rotation and compression
- **Multiple log levels**: error, warn, info, http, verbose, debug
- **Optional Sentry integration** for error tracking

### RequestContextService (`request-context.service.ts`)
Uses Node.js AsyncLocalStorage to:
- Track request IDs across async operations
- Maintain request context without passing through function parameters
- Automatically attach request IDs to all log entries

### HttpLoggerMiddleware (`http-logger.middleware.ts`)
Express middleware that:
- Generates or captures request IDs from headers (`x-request-id`, `x-correlation-id`)
- Logs incoming HTTP requests with method, URL, IP, user agent
- Logs HTTP responses with status code, duration, content length
- Sets `x-request-id` header on responses

### LoggerModule (`logger.module.ts`)
NestJS module that:
- Registers logger services as global providers
- Makes logging available throughout the application
- Configures the HTTP logging middleware

## Environment Variables

Configure the logger using these environment variables:

```bash
# Log level (error, warn, info, http, verbose, debug)
LOG_LEVEL=info

# Directory for log files (relative or absolute path)
LOG_DIR=logs

# Application name (used in log file names)
APP_NAME=enginedge-datalake

# Enable/disable console output
LOG_ENABLE_CONSOLE=true

# Enable/disable file logging
LOG_ENABLE_FILES=true

# Maximum size of each log file before rotation
LOG_MAX_SIZE=20m

# How long to keep log files
LOG_MAX_FILES=14d

# Optional: Sentry DSN for error tracking
SENTRY_DSN=

# Optional: Sentry environment
SENTRY_RELEASE=

# Optional: Sentry trace sample rate (0.0 to 1.0)
SENTRY_TRACES_SAMPLE_RATE=0
```

## Usage

### Basic Logging

```typescript
import { MyLogger } from './infrastructure/logging/logger.service';

@Injectable()
export class MyService {
  constructor(private readonly logger: MyLogger) {}

  doSomething() {
    this.logger.info('Operation started', 'MyService');
    this.logger.debug('Debug details', { userId: 123 });
    this.logger.warn('Warning message', 'MyService');
    this.logger.error('Error occurred', error.stack, 'MyService');
  }
}
```

### HTTP Request Logging

HTTP requests are automatically logged when the `HttpLoggerMiddleware` is configured in `app.module.ts`:

```typescript
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(HttpLoggerMiddleware).forRoutes('*');
  }
}
```

Example output:
```
2025-11-09 10:30:45.123 ℹ INFO    [req:abc-123] [HTTP] (observability.controller.ts:15:8): → GET /api/health
2025-11-09 10:30:45.150 ℹ INFO    [req:abc-123] [HTTP] (observability.controller.ts:15:8): ← GET /api/health 200 27ms
```

### Request Context

The request context automatically tracks request IDs across async operations:

```typescript
import { RequestContextService } from './infrastructure/logging/request-context.service';

@Injectable()
export class MyService {
  constructor(
    private readonly logger: MyLogger,
    private readonly context: RequestContextService,
  ) {}

  async processRequest() {
    // Request ID is automatically available
    const requestId = this.context.getRequestId();
    
    // All logs in this request will include the request ID
    this.logger.info('Processing request', 'MyService');
    
    // Even in async operations
    await this.asyncOperation();
    this.logger.info('Request complete', 'MyService');
  }
}
```

## Log Files

The logger creates several log files in the configured `LOG_DIR`:

- `{APP_NAME}-YYYY-MM-DD-combined.log` - All log entries (JSON format)
- `{APP_NAME}-YYYY-MM-DD-error.log` - Error level logs only (JSON format)
- `{APP_NAME}-YYYY-MM-DD-exceptions.log` - Unhandled exceptions
- `{APP_NAME}-YYYY-MM-DD-rejections.log` - Unhandled promise rejections

Logs are automatically:
- Rotated daily based on the date pattern
- Compressed (gzipped) after rotation
- Cleaned up after the retention period (14 days by default)

## Security Features

### Automatic Redaction

Sensitive fields are automatically redacted from logs:
- password, pass, pwd
- token, access_token, refresh_token
- authorization
- apiKey, apikey, client_secret, secret
- cookie, set-cookie

Example:
```typescript
this.logger.info('User login', { 
  username: 'john',
  password: 'secret123'  // Will be logged as '[REDACTED]'
});
```

## Console Output Format

Console logs use a human-readable format with:
- Timestamp with milliseconds
- Color-coded log levels with icons
- Request ID (when available)
- Context label
- Source file location
- Pretty-printed objects

Example:
```
2025-11-09 10:30:45.123 ℹ INFO    [req:abc-123] [ObservabilityController] (observability.controller.ts:15:8): Health check passed status=healthy uptime=123.45
```

## File Output Format

File logs use JSON format for easy parsing and analysis:

```json
{
  "timestamp": "2025-11-09T10:30:45.123Z",
  "level": "info",
  "message": "Health check passed",
  "context": "ObservabilityController",
  "requestId": "abc-123",
  "sourceAbs": "/app/src/observability.controller.ts:15:8"
}
```

## Migration from KafkaLoggerService

If you're migrating from the old `KafkaLoggerService`:

1. The new logger is a drop-in replacement
2. Update `main.ts` to use `MyLogger` instead of `KafkaLoggerService`
3. Update `app.module.ts` to import `LoggerModule` instead of providing `KafkaLoggerService`
4. Remove the old `kafka-logger.service.ts` file when ready
5. Update any direct imports to use the new service

The API is similar, so most code should work without changes:
```typescript
// Old
this.logger.log('message', { context: 'MyService' });

// New (both work)
this.logger.log('message', 'MyService');
this.logger.info('message', 'MyService');
```
