# ── Build stage ───────────────────────────────────────────────────────────────
FROM node:20-slim AS builder

# openssl is required by Prisma's query engine
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

WORKDIR /repo

# Copy workspace manifests first for better layer caching
COPY package.json yarn.lock ./
COPY apps/backend/package.json ./apps/backend/
COPY packages/shared/package.json ./packages/shared/

# Install all workspace dependencies
RUN yarn install --frozen-lockfile --non-interactive

# Copy source
COPY apps/backend/ ./apps/backend/
COPY packages/ ./packages/

# Generate Prisma client then compile TypeScript
WORKDIR /repo/apps/backend
RUN yarn prisma generate
RUN yarn build

# ── Production image ──────────────────────────────────────────────────────────
FROM node:20-slim

RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

WORKDIR /repo

# Keep monorepo root structure so Node can resolve hoisted yarn modules
COPY --from=builder /repo/package.json ./
COPY --from=builder /repo/node_modules ./node_modules

# Backend app files
COPY --from=builder /repo/apps/backend/package.json ./apps/backend/
COPY --from=builder /repo/apps/backend/dist ./apps/backend/dist
COPY --from=builder /repo/apps/backend/prisma ./apps/backend/prisma

# Workspace-local node_modules (may be empty but included for safety)
COPY --from=builder /repo/apps/backend/node_modules ./apps/backend/node_modules

EXPOSE 3000

WORKDIR /repo/apps/backend
CMD ["node", "dist/apps/backend/src/index.js"]
