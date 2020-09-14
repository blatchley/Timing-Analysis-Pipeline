#!/bin/bash

RED='\033[0;31m'
NC='\033[0m'

help () {
    printf "Usage:\n"
    printf "Run using prebuild docker image:\n"
    printf "\t./run.sh source_dir out_dir\n\n"
    printf "Manually build the docker image and run it:\n"
    printf "\t./run.sh -b source_dir out_dir\n"
    exit 0
}

check_path () {
    local path=$1
    local number=$2
    [ ! -d $path ] && printf "${RED}The ${number} argument is not a directory${NC}\n\n" && help
    [ "${path:0:1}" != "/" ] && printf "${RED}The ${number} argument is not an absolute path${NC}\n\n" && help
}

[ ! -x "$(command -v docker)" ] && printf "${RED}Could not find docker, make sure that you have docker installed${NC}" && exit 0

if [ "$1" == "-b" ] && [ $# -eq 3 ]; then
    check_path $2 "second"
    check_path $3 "third"

    has_tools=$(docker images | grep ct-analysis | wc -l)
    [ $has_tools < 1 ] && docker build -t ct-analysis -f Dockerfile .
    docker run --rm -it -v ${2}:/root/source -v ${3}:/root/out ct-analysis

elif [ $# -eq 2 ]; then
    check_path $1 "first"
    check_path $2 "second"

    docker run --rm -it -v ${1}:/root/source -v ${2}:/root/out blatchley/ct-analysis:latest

else
    help
fi
