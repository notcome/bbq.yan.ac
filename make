#!/bin/sh
ghc *.hs Acid/*.hs Data/*.hs Layout/*.hs Middleware/*.hs Page/*.hs -odir tmp -hidir tmp -O -o bbq
