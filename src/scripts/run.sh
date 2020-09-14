#!/bin/bash
SRC_DIR="/usr/share/sources"
COMMON_DIR="${SRC_DIR}/common"
FLOWTRACKER_DIR="${SRC_DIR}/flowtracker"
DUDECT_DIR="${SRC_DIR}/dudect"
DUDECT_ISNTALL_DIR="/usr/share/dudect"
SETTINGS="${SRC_DIR}/settings/settings.h"
SETTINGS_DIR="${SRC_DIR}/settings/"
FLOWTRACKER_XML="${FLOWTRACKER_DIR}/encrypt_key.xml"
CANDIDATE_DIR="/root/source"
OUT_DIR="/root/out"
ENCRYPT="${CANDIDATE_DIR}/encrypt.c"
API="${CANDIDATE_DIR}/api.h"
COMPILED_DIR="/tmp/compiled"

RED='\033[0;31m'
NC='\033[0m'

error () {
    local msg=$1
    printf "${RED}Error: ${msg}${NC}\n"
    exit 1
}

dudect () {
    [ ! -f "${COMPILED_DIR}/dudect" ] && error "Could not find compiled dudect file"
    printf "Executing dudect for ${DUDECT_TIMEOUT} seconds\n"
    timeout $DUDECT_TIMEOUT stdbuf -oL "${COMPILED_DIR}/dudect" > "${OUT_DIR}/dudect.out"
    [ $? -ne 0 -a $? -ne 124 ] && printf "${RED}Error: An error occurred while running dudect${NC}\n" && return
    printf "Finished running dudect\n"
}

ctgrind () {
    [ ! -f "${COMPILED_DIR}/ctgrind" ] && error "Could not find compiled ctgrind file"
    printf "Executing ctgrind with sample size ${CTGRIND_SAMPLE_SIZE}\n"
    valgrind "${COMPILED_DIR}/ctgrind" > "${OUT_DIR}/ctgrind.out" 2>&1
    [ $? -ne 0 ] && printf "${RED}Error: An error occurred while running ctgrind${NC}\n" && return
    printf "Finished running ctgrind\n"
}

flowtracker () {
    [ ! -f "${COMPILED_DIR}/flowtracker.rbc" ] && error "Could not find compiled flowtracker file"
    printf "Executing flowtracker\n"
    [ ! -d "${OUT_DIR}/flowtracker" ] && mkdir "${OUT_DIR}/flowtracker"
    cd "${OUT_DIR}/flowtracker"
    opt -basicaa -load AliasSets.so -load DepGraph.so -load bSSA2.so -bssa2 \
        -xmlfile $FLOWTRACKER_XML \
        "${COMPILED_DIR}/flowtracker.rbc" \
        2> "${OUT_DIR}/flowtracker.out"
    [ $? -ne 0 ] && printf "${RED}Error: An error occurred while running flowtracker${NC}\n" && return
    printf "Finished running flowtracker\n"
}


# Verify that required files are in /root/source/
printf "Verifying mounted source and output folders\n"
[ ! -d "${CANDIDATE_DIR}" ] && error "No source directory mounted"
[ ! -d "${OUT_DIR}" ] && error "No output directory mounted"
[ ! -f "${ENCRYPT}" ] && error "Could not find the encrypt.c in source directory"
[ ! -f "${API}" ] && error "Could not find the api.h in source directory"

# Check if user provided settings.h and load settings
printf "Reading user settings\n"
[ -f "${CANDIDATE_DIR}/settings.h" ] && SETTINGS="${CANDIDATE_DIR}/settings.h" && SETTINGS_DIR="${CANDIDATE_DIR}/"
while read -r def var val; do
    newval=$(echo "$val" | cut -d ' ' -f1 | cut -f1 ) #remove comments and white space
    printf -v $var "$newval"
done < <(cat $SETTINGS | sed 's/\r$//' | grep -E '^#define[ \t]+[a-zA-Z_][0-9a-zA-Z_]+')

[ ! "${ANALYSE_ENCRYPT}" == "1" ] && FLOWTRACKER_XML="${FLOWTRACKER_DIR}/decrypt_key.xml"

# Compile setup
[ ! -d "${COMPILED_DIR}" ] && mkdir ${COMPILED_DIR}
CFLAGS="-std=c99 -Wall -Wextra -Wshadow -O2 -Wfatal-errors"
LIBS="-lm"
DUDECT_OBJS="${DUDECT_ISNTALL_DIR}/src/cpucycles.o \
    ${DUDECT_ISNTALL_DIR}/src/fixture.o \
    ${DUDECT_ISNTALL_DIR}/src/random.o \
    ${DUDECT_ISNTALL_DIR}/src/ttest.o \
    ${DUDECT_ISNTALL_DIR}/src/percentile.o"
DUDECT_INCS="-I${DUDECT_ISNTALL_DIR}/inc/"
C_FILES=$(find -path ".${CANDIDATE_DIR}/*.c")

# Compile encrypt.c with dudect
printf "Compiling with dudect\n"
COMPILED_FILES=""
for file in $C_FILES; do
    file_basename=$(basename ${file} .c)
    [[ "$file_basename" == "genkat_aead" ]] && continue
    file_compiled="${COMPILED_DIR}/${file_basename}.o"
    gcc $CFLAGS -I$COMMON_DIR -I$CANDIDATE_DIR -c $file -o $file_compiled
    [ $? -ne 0 ] && error "Error compiling provided src"
    COMPILED_FILES="$COMPILED_FILES $file_compiled"
done

gcc $CFLAGS $DUDECT_INCS -I$COMMON_DIR -I$CANDIDATE_DIR -I$SETTINGS_DIR -o "${COMPILED_DIR}/dudect" \
     "${DUDECT_DIR}/dut.c" $DUDECT_OBJS $COMPILED_FILES $LIBS
[ $? -ne 0 ] && error "Error compiling provided src with dudect"

# Compile encrypt.c with ctgrind
printf "Compiling with ctgrind\n"
CFLAGS="$CFLAGS -ggdb"
COMPILED_FILES=""
for file in $C_FILES; do
    file_basename=$(basename ${file} .c)
    [[ "$file_basename" == "genkat_aead" ]] && continue
    file_compiled="${COMPILED_DIR}/${file_basename}.o"
    gcc $CFLAGS -I$COMMON_DIR -I$CANDIDATE_DIR -c $file -o $file_compiled
    [ $? -ne 0 ] && error "Error compiling provided src"
    COMPILED_FILES="$COMPILED_FILES $file_compiled"
done

gcc $CFLAGS $DUDECT_INCS -I$COMMON_DIR -I$CANDIDATE_DIR -I$SETTINGS_DIR "${SRC_DIR}/ctgrind/taint.c" /usr/lib/libctgrind.so \
    -o "${COMPILED_DIR}/ctgrind" $COMPILED_FILES "${DUDECT_ISNTALL_DIR}/src/random.o" $LIBS
[ $? -ne 0 ] && error "Error compiling provided src with ctgrind"

# Compile encrypt.c with flowtracker
printf "Compiling with flowtracker\n"

FLOWTRACKER_BC="${COMPILED_DIR}/flowtracker.bc"
FLOWTRACKER_COMPILED="${COMPILED_DIR}/flowtracker.rbc"
clang -emit-llvm -I${COMPILED_DIR} -I$COMMON_DIR -g -c $ENCRYPT -o $FLOWTRACKER_BC
[ $? -ne 0 ] && error "Error compiling provided src to llvm"
opt -instnamer -mem2reg $FLOWTRACKER_BC > $FLOWTRACKER_COMPILED
[ $? -ne 0 ] && error "Error compiling provided src with flowtracker"

# Execute
printf "Starting tool execution\n"

dudect &
ctgrind &
flowtracker &
wait

# Write summary
SUMMARY="Summary of running tools on the provied code\n\nResult of running dudect:\n"
output=$(tail -n 3 ${OUT_DIR}/dudect.out)
if [[ "$output" =~ "Definitely not" || "$output" =~ "Probably not" || "$output" =~ "maybe" ]]; then
    SUMMARY="${SUMMARY}Last 3 iterations gave\n${output}\nFull dudect report can be found in dudect.out in the output directory\n\n"
else
    SUMMARY="${SUMMARY}DUDECT gave no output in the time allotted\n\n"
fi

SUMMARY="${SUMMARY}Result of running ctgrind:\n"
output=$(tail -n 1 ${OUT_DIR}/ctgrind.out)
SUMMARY="${SUMMARY}${output}\nFull ctgrind report can be found in ctgrind.out in the output directory\n\n"

SUMMARY="${SUMMARY}Result of running flowtracker:\n"
output=$(tail -n 1 ${OUT_DIR}/flowtracker.out)
SUMMARY="${SUMMARY}${output}\nVulnerable Subgraphs can be found in flowtracker directory in the output directory\n"

echo ""
echo ""
echo ""
printf "$SUMMARY" > ${OUT_DIR}/summary.txt
printf "$SUMMARY"

# Clean tmp files
rm -rf $COMPILED_DIR
