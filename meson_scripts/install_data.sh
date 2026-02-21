#!/bin/bash

shopt -s extglob
mkdir -p $DESTDIR/$1
if [ -d "$2" ]; then
	cp -a $2/ $DESTDIR/$1 || true
else
	cp -a $2 $DESTDIR/$1 || true
fi
