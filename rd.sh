#!/bin/sh


if [ -n "$TC" ]; then
  echo "Running tests..."
  # --latest-only
  # --keep-asm-on-failure 
  docker-compose exec -T box bash -c "jai-linux build.jai && tests/test_compiler ./out/jcc --verbose --failfast --verbose $1"
  exit 0
fi

echo "Compiling ./c/main.c"
docker-compose exec -T box bash -c "jai-linux build.jai && ./out/jcc -- ./c/main.c $1"
