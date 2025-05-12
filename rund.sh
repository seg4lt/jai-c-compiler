#!/bin/sh

docker-compose exec box bash -c 'jai build.jai && ./out/jaicc -- ./c/main.c && ./c/main'
