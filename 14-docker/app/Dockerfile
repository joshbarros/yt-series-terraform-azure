# EP14 — Production Dockerfile for Next.js (standalone output).
#
# Multi-stage build:
#   Stage 1 (deps):    install node_modules
#   Stage 2 (builder): build the Next.js app with standalone output
#   Stage 3 (runner):  minimal production image (~150MB vs ~1GB)
#
# Docs: https://nextjs.org/docs/app/building-your-application/deploying#docker-image

# --- Stage 1: Dependencies ---
FROM node:20-alpine AS deps
WORKDIR /app

# Copy package files first for better Docker layer caching.
# If package.json hasn't changed, npm ci is skipped on rebuild.
COPY package.json package-lock.json ./
RUN npm ci --production=false

# --- Stage 2: Build ---
FROM node:20-alpine AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# next.config.ts MUST have: output: "standalone"
# This bundles a minimal server — drops 85% of node_modules.
RUN npm run build

# --- Stage 3: Production runner ---
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

# Don't run as root in production.
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy only what the standalone server needs.
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000

# The standalone server is a single server.js file.
CMD ["node", "server.js"]
