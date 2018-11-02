#!/usr/bin/with-contenv sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

export NODE_ENV=production

cd /opt/nginx-proxy-manager
exec node --abort_on_uncaught_exception --max_old_space_size=250 /opt/nginx-proxy-manager/src/backend/index.js
