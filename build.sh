#!/usr/bin/env bash

DL_PAPER="https://papermc.io/api/v1/paper/1.12.2/1618/download"
MD5_PAPER="4c81838696da39b1b06987e81ca8b0af"

DL_PAPERBIN="https://i.binclub.dev/PaperBin.jar"
MD5_PAPERBIN="6ee1fceb3311fb4c9be82cafcf65bb9c"

GIT_PAPER="https://github.com/PaperMC/Paper.git"
GIT_PAPER_BRANCH="ver/1.12.2"

FERNFLOWER_JAR="https://the.bytecode.club/fernflower.jar"
MD5_FERNFLOWER="c4e6f208b7cd6cd3d8ef7edf1161c039"

###

set -e

PROJECT_ROOT="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

PAPERBIN_CONFIG="$PROJECT_ROOT"/paperbin.properties
PAPERBIN_COMPILED="$PROJECT_ROOT"/work/compiled/
PAPERBIN_DECOMPILED="$PROJECT_ROOT"/work/decompiled/

###

mkdir -p "$PROJECT_ROOT"/work
rm -rf "$PROJECT_ROOT"/work/*

###

echo "preparing paper"

mkdir "$PROJECT_ROOT"/work/server
cd "$PROJECT_ROOT"/work/server

curl $DL_PAPER -o paper.jar
if md5sum -c <<< "$MD5_PAPER paper.jar" | grep -q "paper.jar: OK"; then
  echo "paper download successful"
else
  echo "paper download failed"
  exit 1
fi

echo "reject eula to stop server after class generation"
{
  echo "eula=false"
} > eula.txt

###

echo "preparing paperbin"

curl $DL_PAPERBIN -o paperbin.jar
if md5sum -c <<< "$MD5_PAPERBIN paperbin.jar" | grep -q "paperbin.jar: OK"; then
  echo "paperbin download successful"
else
  echo "paperbin download failed"
  exit 1
fi

cp "$PAPERBIN_CONFIG" ./paperbin.properties
sed -i 's/debug=false/debug=true/g' ./paperbin.properties

###

echo "generate classes"

java -noverify -jar paperbin.jar paper.jar debug || echo "classes generated"

###

cd "$PROJECT_ROOT"/work

echo "downloading fernflower"

curl $FERNFLOWER_JAR -o fernflower.jar
if md5sum -c <<< "$MD5_FERNFLOWER fernflower.jar" | grep -q "fernflower.jar: OK"; then
  echo "fernflower download successful"
else
  echo "fernflower download failed"
  exit 1
fi

echo "decompiling paperbin changes"

mkdir "$PAPERBIN_COMPILED"
mkdir "$PAPERBIN_DECOMPILED"

unzip "$PROJECT_ROOT"/work/server/paperbin_patched.jar -d "$PROJECT_ROOT"/work/compiled

java -jar fernflower.jar -hes=0 -hdc=0 "$PAPERBIN_COMPILED"/net/minecraft/server/v1_12_R1/ "$PAPERBIN_DECOMPILED"

echo "change namespace"

for f in "$PAPERBIN_DECOMPILED"/*
do
  sed -i -e 's/.v1_12_R1//g' $f
done

###

echo "generate preparing paper source"

git clone "$GIT_PAPER" src
cd src || exit
git checkout "$GIT_PAPER_BRANCH"

cp "$PROJECT_ROOT"/importmcdev.sh "$PROJECT_ROOT"/work/src/scripts/

git add .
git commit -m "class import"
./paper jar

cp "$PAPERBIN_DECOMPILED"/* "$PROJECT_ROOT"/work/src/Paper-Server/src/main/java/net/minecraft/server/
cd "$PROJECT_ROOT"/work/src/Paper-Server/
git add .
git commit -m "paperbin"
cd ..
./paper rebuild
./paper jar

cd "$PROJECT_ROOT"
