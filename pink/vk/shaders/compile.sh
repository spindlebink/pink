#!/usr/bin/env bash

BASEDIR=$(dirname "$0")
glslangValidator -V "$BASEDIR/shader.vert" -o "$BASEDIR/shader.vert.spv"
glslangValidator -V "$BASEDIR/shader.frag" -o "$BASEDIR/shader.frag.spv"
