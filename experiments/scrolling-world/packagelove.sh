#!/bin/bash
cp -r ../../vendor ./vendor
cp -r ../../lib ./lib

zip -r scrolling-world.love .
rm -rf ./vendor
rm -rf ./lib
mv scrolling-world.love ~/Desktop
