# Base image for Murror API database migrations
# Contains pre-installed npm dependencies to speed up migration image builds
# Tag with Prisma version: ghcr.io/murror/murror-migration-base:<prisma-version>

# Stage 1: Build dependencies
FROM node:22.11-alpine AS builder

WORKDIR /app

# Install system dependencies needed for Prisma and TypeScript compilation
RUN apk add --no-cache build-base libc6-compat python3

# Create package.json with all migration dependencies
RUN echo '{ \
  "name": "prisma-migration", \
  "version": "1.0.0", \
  "dependencies": { \
    "prisma": "6.10.1", \
    "@prisma/client": "6.10.1", \
    "typescript": "5.8.3", \
    "ts-node": "10.9.2", \
    "@types/node": "22.10.5", \
    "@tsconfig/node22": "22.0.0", \
    "tsconfig-paths": "4.2.0", \
    "commander": "13.1.0", \
    "@aws-sdk/client-s3": "3.750.0", \
    "pino": "9.5.0", \
    "pino-pretty": "13.0.0" \
  }, \
  "scripts": { \
    "prisma:migrate:deploy": "prisma migrate deploy --schema=prisma/schema.murror.prisma", \
    "prisma:seed": "node -r ts-node/register/transpile-only -r tsconfig-paths/register prisma/seed.ts", \
    "preview:setup": "npm run prisma:migrate:deploy && npm run prisma:seed" \
  } \
}' > package.json

# Create tsconfig.json with path mappings for Prisma clients
RUN echo '{ \
  "compilerOptions": { \
    "target": "ES2023", \
    "module": "commonjs", \
    "lib": ["ES2023"], \
    "outDir": "./dist", \
    "rootDir": ".", \
    "esModuleInterop": true, \
    "skipLibCheck": true, \
    "forceConsistentCasingInFileNames": true, \
    "resolveJsonModule": true, \
    "moduleResolution": "node", \
    "types": ["node"], \
    "allowJs": true, \
    "baseUrl": ".", \
    "strictNullChecks": true, \
    "noImplicitAny": false, \
    "experimentalDecorators": true, \
    "emitDecoratorMetadata": true, \
    "paths": { \
      "@generated/*": ["./src/generated/*"], \
      "@src/*": ["./src/*"], \
      "../src/generated/.prisma/client": ["./src/generated/.prisma/client"], \
      "../src/generated/.prisma/legacy-client": ["./src/generated/.prisma/legacy-client"], \
      "../../src/generated/.prisma/client": ["./src/generated/.prisma/client"], \
      "../../src/generated/.prisma/legacy-client": ["./src/generated/.prisma/legacy-client"], \
      "../../../src/generated/.prisma/client": ["./src/generated/.prisma/client"], \
      "../../../src/generated/.prisma/legacy-client": ["./src/generated/.prisma/legacy-client"] \
    } \
  }, \
  "ts-node": { \
    "transpileOnly": true, \
    "files": true, \
    "require": ["tsconfig-paths/register"], \
    "compilerOptions": { \
      "module": "commonjs", \
      "allowJs": true \
    } \
  }, \
  "include": ["prisma/**/*", "src/**/*"], \
  "exclude": ["node_modules", "dist"] \
}' > tsconfig.json

# Install dependencies
RUN npm install --no-audit --no-fund

# Stage 2: Runtime base image
FROM node:22.11-alpine

RUN apk add --no-cache libc6-compat && \
    addgroup -g 1001 -S migration && \
    adduser -S migration -u 1001 -G migration

RUN mkdir -p /app && chown migration:migration /app

WORKDIR /app

# Copy pre-installed dependencies and config from builder
COPY --from=builder --chown=migration:migration /app/node_modules ./node_modules
COPY --from=builder --chown=migration:migration /app/package.json ./
COPY --from=builder --chown=migration:migration /app/tsconfig.json ./
