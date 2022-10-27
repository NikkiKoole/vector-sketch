#!/bin/bash
cp -r ../../vendor ./vendor
cp -r ../../lib ./lib
cp ../../resources.zip ./resources.zip

zip -r scrolling-world.love .
rm -rf ./vendor
rm -rf ./lib
mv scrolling-world.love ~/Desktop
