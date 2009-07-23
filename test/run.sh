#!/bin/sh

cd ..

git submodule init
git submodule update

cd test

ruby run-tests.rb