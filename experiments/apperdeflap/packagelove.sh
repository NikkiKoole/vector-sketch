#!/bin/bash
cp -r ../../vendor ./vendor
cp -r ../../lib ./lib
#cp ../../resources.zip ./resources.zip
#cp -r ../../resources ./resources

cp ../../lib/audio.lua ./
zip -r flap.love . -x "./ignoreDir/*" 
rm -rf ./vendor
rm -rf ./lib
rm -rf ./resources
mv flap.love ~/Desktop
