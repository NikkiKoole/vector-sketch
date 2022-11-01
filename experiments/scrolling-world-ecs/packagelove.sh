#!/bin/bash
cp -r ../../vendor ./vendor
cp -r ../../lib ./lib
cp ../../resources.zip ./resources.zip
cp -r ../../resources ./resources

zip -r scrolling-world.love .
rm -rf ./vendor
rm -rf ./lib
rm -rf ./resources
mv scrolling-world.love ~/Desktop
