#!/bin/sh
set -eu

if [ "$#" -eq 0 ] || [ "${1#-}" != "$1" ]; then
  exec /usr/sbin/init
fi

exec "$@"