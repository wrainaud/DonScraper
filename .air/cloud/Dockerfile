FROM node:6.17.1
# npm 6 understands the existing v1 lockfile and still runs on Node 6.
RUN mkdir -p /opt/npm && curl -fsSL https://registry.npmjs.org/npm/-/npm-6.14.18.tgz | tar xz -C /opt/npm --strip-components=1
RUN ln -sf /opt/npm/bin/npm-cli.js /usr/local/bin/npm && ln -sf /opt/npm/bin/npx-cli.js /usr/local/bin/npx
WORKDIR /app
