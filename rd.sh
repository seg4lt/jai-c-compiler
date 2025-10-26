#!/bin/sh

if [ -n "$DOCKER" ]; then
    if [ -n "$TC" ]; then
        echo "Running tests..."
        # --latest-only
        # --keep-asm-on-failure
        docker-compose exec -T box bash -c "jai-macos build.jai && tests/test_compiler ./out/jcc --verbose --failfast --verbose $1"
        exit 0
    fi

    echo "Compiling ./c/main.c"
    docker-compose exec -T box bash -c "jai-macos build.jai && ./out/jcc -- ./c/main.c $1"
    exit 0
fi

if [ -n "$TC" ]; then
    echo "Running tests..."
    # --latest-only
    # --keep-asm-on-failure
    jai-linux build.jai && tests/test_compiler ./out/jcc --verbose --failfast --verbose $1
    exit 0
fi

echo "Compiling ./c/main.c"
jai-linux build.jai && ./out/jcc -- ./c/main.c $1
exit 0
