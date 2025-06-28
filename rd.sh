#!/bin/sh


if [ -n "$TC" ]; then
  echo "Running tests..."
  docker-compose exec box bash -c "jai build.jai && tests/test_compiler ./out/jcc --verbose --failfast $1"
  exit 0
fi

echo "Compiling ./c/main.c"
docker-compose exec box bash -c "jai build.jai && ./out/jcc -- ./c/main.c $1"
