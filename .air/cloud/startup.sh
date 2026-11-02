#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
echo "Preparing compatible Node and MongoDB development runtimes"
docker build --build-arg HTTP_PROXY --build-arg HTTPS_PROXY --build-arg http_proxy --build-arg https_proxy -t donscraper-dev .air/cloud
docker image inspect mongo:4.0 >/dev/null 2>&1 || docker pull mongo:4.0
stamp="$(sha256sum package-lock.json package.json | sha256sum | cut -d' ' -f1)"
if [[ ! -f node_modules/.air-lock || "$(cat node_modules/.air-lock)" != "$stamp" ]]; then
  echo "Installing locked dependencies"
  docker run --rm --network host -e HTTP_PROXY -e HTTPS_PROXY -e http_proxy -e https_proxy -v "$PWD:/app" donscraper-dev node /opt/npm/bin/npm-cli.js ci --unsafe-perm
  docker run --rm -v "$PWD:/app" donscraper-dev chown -R "$(id -u):$(id -g)" /app/node_modules
  echo "$stamp" > node_modules/.air-lock
fi
docker volume create donscraper-data >/dev/null
if ! docker container inspect donscraper-mongo >/dev/null 2>&1; then
  docker run -d --name donscraper-mongo --network host -v donscraper-data:/data/db mongo:4.0 --bind_ip 127.0.0.1
else
  docker start donscraper-mongo >/dev/null
fi
# Persist a generated local session key without committing it.
mkdir -p "$HOME/.local/share/donscraper"
key="$HOME/.local/share/donscraper/session-key"
if [[ ! -f "$key" ]]; then (umask 077; openssl rand -hex 32 > "$key"); fi
docker rm -f donscraper-app >/dev/null 2>&1 || true
# Wait for the database in the background so task startup returns promptly.
docker run -d --name donscraper-app --network host -v "$PWD:/app"   -e MONGODB=mongodb://127.0.0.1:27017/donscraper   -e SESSION_SECRET="$(cat "$key")" -e PORT=3000   -e HTTP_PROXY -e HTTPS_PROXY -e http_proxy -e https_proxy   donscraper-dev sh -c 'until node -e "require(\"net\").connect(27017,\"127.0.0.1\").on(\"connect\",function(){process.exit(0)}).on(\"error\",function(){process.exit(1)})"; do sleep 2; done; exec node app.js'
healthcheck() {
  echo "Waiting for MongoDB and the DonScraper web application"
  while ! curl -fsS -H 'Host: air-preview.example' http://127.0.0.1:3000/ > /tmp/donscraper-home.html; do
    if [[ "$(docker inspect -f '{{.State.Running}}' donscraper-app)" != true ]]; then
      docker logs donscraper-app
      return 1
    fi
    echo "Waiting for application readiness..."
    sleep 3
  done
  grep -q 'Home - DonScraper' /tmp/donscraper-home.html
  curl -fsS http://127.0.0.1:3000/css/styles.css | grep -q 'body'
  docker exec donscraper-mongo mongo --quiet --eval 'if (db.runCommand({ping:1}).ok !== 1) quit(1)'
  docker exec donscraper-app node -e 'require("node-sass").renderSync({data:"body { color: red; }"}); console.log("Native Sass compilation passed")'
  echo "DonScraper healthcheck passed"
}
if [[ "${AIR_STARTUP_MODE:-}" == warmup ]]; then healthcheck; fi
