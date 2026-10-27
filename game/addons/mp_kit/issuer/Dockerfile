# The MpKit issuer as a container (Fly reads this next to fly.toml; any host that runs Docker can too).
FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY server.mjs keys.mjs ./
COPY lib ./lib
ENV NODE_ENV=production
USER node
EXPOSE 8090
CMD ["node", "server.mjs"]
