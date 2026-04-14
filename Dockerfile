FROM node:22.20.0

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci

COPY . .

RUN chown -R node:node /app

USER node

ENV DATABASE_PATH=/data/jobs.sqlite

CMD ["npm", "start"]
