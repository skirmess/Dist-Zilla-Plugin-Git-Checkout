#!/bin/bash

set -e

cd -- "$(dirname -- "$0")"
BASE_DIR=$PWD

rm -rf test test.bundle test2.bundle

mkdir test
cd test
git init .

git config user.email test@example.com
git config user.name Test

perl -MPath::Tiny -e 'path(q{A})->spew(q{5})'
git add A
git commit -m 'initial commit'
git tag v47

perl -MPath::Tiny -e 'path(q{A})->spew(q{7})'
git add A
git commit -m 'second commit'

git tag my-tag

git branch dev
git checkout dev

perl -MPath::Tiny -e 'path(q{A})->spew(q{11})'
perl -MPath::Tiny -e 'path(q{B})->spew(q{13})'
git add A B

git commit -m 'commit on dev branch'

git checkout master

git bundle create ../test.bundle --branches --tags HEAD


# ---
cd -- "$BASE_DIR"

rm -rf test

mkdir test
cd test
git init .

git config user.email test@example.com
git config user.name Test

perl -MPath::Tiny -e 'path(q{C})->spew(q{419})'
git add C
git commit -m 'initial commit'

git bundle create ../test2.bundle --branches --tags HEAD
