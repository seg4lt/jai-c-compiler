#!/bin/sh

docker-compose exec box bash -c "jai build.jai && ./out/jcc -- ./c/main.c $1"
