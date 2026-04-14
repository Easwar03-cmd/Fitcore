# ── Build stage ──────────────────────────────────────────────────────────────
FROM node:20-slim AS builder

# openssl is required by Prisma's query engine
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

WORKDIR /repo

# Copy package manifests first so Docker layer-caches npm ci
COPY apps/backend/package.json apps/backend/package-lock.json* ./apps/backend/

# Install all deps (devDeps needed for tsc + prisma generate)
WORKDIR /repo/apps/backend
RUN npm ci

# Copy source files
WORKDIR /repo
COPY apps/backend/ ./apps/backend/
COPY packages/ ./packages/

# Generate Prisma client then compile TypeScript
WORKDIR /repo/apps/backend
RUN npx prisma generate
RUN npm run build

# ── Production image ──────────────────────────────────────────────────────────
FROM node:20-slim

RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

WORKDIR /repo/apps/backend

# Copy only what runtime needs
COPY --from=builder /repo/apps/backend/package.json ./
COPY --from=builder /repo/apps/backend/node_modules ./node_modules
COPY --from=builder /repo/apps/backend/dist ./dist
COPY --from=builder /repo/apps/backend/prisma ./prisma

EXPOSE 3000

CMD ["node", "dist/apps/backend/src/index.js"]
