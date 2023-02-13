#!/bin/bash

set -e

RESET="0m"
NORMAL="0"
BOLD="1"
BLACK=";30m"
RED=";31m"
GREEN=";32m"
YELLOW=";33m"
BLUE=";34m"
MAGENTA=";35m"
CYAN=";36m"
WHITE=";37m"

function color() {
  echo "\e[$1$2"
}

function finally() {
  local EXIT_CODE="${1:-0}"
  echo -e "❌ Benchmark $(color $BOLD $RED)failed$(color $RESET)."
  if [ ! -z "$2" ]; then
    echo "> $2"
  fi
  exit "${EXIT_CODE}"
}

trap 'finally $? "The benchmark was aborted before its completion."' INT

function parseReadResult() {
  echo "$(($(cat $TARGET/.diskmark.json | grep -A15 '"name" : "'"$1"'"' | grep bw_bytes | cut -d: -f2 | sed s:,::g)/1024/1024)) MB/s, $(cat $TARGET/.diskmark.json | grep -A15 '"name" : "'"$1"'"' | grep -m1 iops | cut -d: -f2 | cut -d. -f1 | sed 's: ::g') IO/s"
}

function parseWriteResult() {
  echo "$(($(cat $TARGET/.diskmark.json | grep -A80 '"name" : "'"$1"'"' | grep bw_bytes | sed '2!d' | cut -d: -f2 | sed s:,::g)/1024/1024)) MB/s, $(cat $TARGET/.diskmark.json | grep -A80 '"name" : "'"$1"'"' | grep iops | sed '7!d' | cut -d: -f2 | cut -d. -f1 | sed 's: ::g') IO/s"
}

function parseRandomReadResult() {
  echo "$(($(cat $TARGET/.diskmark.json | grep -A15 '"name" : "'"$1"'"' | grep bw_bytes | sed 's/        "bw_bytes" : //g' | sed 's:,::g' | awk '{ SUM += $1} END { printf "%.0f", SUM }')/1024/1024)) MB/s, $(cat $TARGET/.diskmark.json | grep -A15 '"name" : "'"$1"'"' | grep iops | sed 's/        "iops" : //g' | sed 's:,::g' | awk '{ SUM += $1} END { printf "%.0f", SUM }' | cut -d. -f1) IO/s"
}

function parseRandomWriteResult() {
  echo "$(($(cat $TARGET/.diskmark.json | grep -A80 '"name" : "'"$1"'"' | grep bw_bytes | sed 's/        "bw_bytes" : //g' | sed 's:,::g' | awk '{ SUM += $1} END { printf "%.0f", SUM }')/1024/1024)) MB/s, $(cat $TARGET/.diskmark.json | grep -A80 '"name" : "'"$1"'"' | grep iops | sed 's/        "iops" : //g' | sed 's:,::g' | awk '{ SUM += $1} END { printf "%.0f", SUM }' | cut -d. -f1) IO/s"
}

function loadDefaultProfile() {
  NAME[0]="SEQ1MQ8T1"
  LABEL[0]="Sequential 1M Q8T1"
  PARAMS[0]="--bs=1M --iodepth=8 --numjobs=1 --rw="
  PARSE[0]="parse"
  COLOR[0]=$(color $NORMAL $YELLOW)
  SIZE[0]=$SIZE

  NAME[1]="SEQ1MQ1T1"
  LABEL[1]="Sequential 1M Q1T1"
  PARAMS[1]="--bs=1M --iodepth=1 --numjobs=1 --rw="
  PARSE[1]="parse"
  COLOR[1]=$(color $NORMAL $YELLOW)
  SIZE[1]=$SIZE

  NAME[2]="RND4KQ32T1"
  LABEL[2]="Random 4K Q32T1"
  PARAMS[2]="--bs=4k --iodepth=32 --numjobs=1 --rw=rand"
  PARSE[2]="parseRandom"
  COLOR[2]=$(color $NORMAL $CYAN)
  SIZE[2]=$(($SIZE / 32))

  NAME[3]="RND4KQ1T1"
  LABEL[3]="Random 4K Q1T1"
  PARAMS[3]="--bs=4k --iodepth=1 --numjobs=1 --rw=rand"
  PARSE[3]="parseRandom"
  COLOR[3]=$(color $NORMAL $CYAN)
  SIZE[3]=$SIZE
}

function loadNVMeProfile() {
  NAME[0]="SEQ1MQ8T1"
  LABEL[0]="Sequential 1M Q8T1"
  PARAMS[0]="--bs=1M --iodepth=8 --numjobs=1 --rw="
  PARSE[0]="parse"
  COLOR[0]=$(color $NORMAL $YELLOW)
  SIZE[0]=$SIZE

  NAME[1]="SEQ128KQ32T1"
  LABEL[1]="Sequential 128K Q32T1"
  PARAMS[1]="--bs=128k --iodepth=32 --numjobs=1 --rw="
  PARSE[1]="parse"
  COLOR[1]=$(color $NORMAL $GREEN)
  SIZE[1]=$SIZE

  NAME[2]="RND4KQ32T16"
  LABEL[2]="Random 4K Q32T16"
  PARAMS[2]="--bs=4k --iodepth=32 --numjobs=16 --rw=rand"
  PARSE[2]="parseRandom"
  COLOR[2]=$(color $NORMAL $CYAN)
  SIZE[2]=$(($SIZE / 32))

  NAME[3]="RND4KQ32T1"
  LABEL[3]="Random 4K Q32T1"
  PARAMS[3]="--bs=4k --iodepth=32 --numjobs=1 --rw=rand"
  PARSE[3]="parseRandom"
  COLOR[3]=$(color $NORMAL $CYAN)
  SIZE[3]=$(($SIZE / 32))
}

TARGET="/disk"
PARTITION=$(df $TARGET | grep /dev | cut -d/ -f3 | cut -d" " -f1)
if [ -z "$PARTITION" ]; then
  DRIVE=""
elif [[ "$PARTITION" == nvme* ]]; then
  loadNVMeProfile
  DRIVE=$(echo $PARTITION | rev | cut -c 3- | rev)
else
  loadDefaultProfile
  DRIVE=$(echo $PARTITION | rev | cut -c 2- | rev)
fi
if [ -z "$DRIVE" ]; then
  DRIVE="unknown"
  DRIVEMODEL="unknown"
  DRIVESIZE="unknown"
else
  DRIVEMODEL=$(cat /sys/block/$DRIVE/device/model | sed 's/ *$//g')
  DRIVESIZE=$(($(cat /sys/block/$DRIVE/size)*512/1024/1024/1024))GB
fi

echo -e "$(color $BOLD $WHITE)Configuration:$(color $RESET)
- Target: $TARGET
- Drive: $DRIVEMODEL ($DRIVE, $DRIVESIZE)
- Size: ${SIZE} MB
- Loops: $LOOPS
- Write Only Zeroes: $WRITEZERO

Benchmark is $(color $BOLD $WHITE)running$(color $RESET), please wait..."

fio --loops=$LOOPS --size=${SIZE[$i]}M --filename=$TARGET/.diskmark.tmp --stonewall --ioengine=libaio --direct=1 --zero_buffers=$WRITEZERO --output-format=json \
  --name=Bufread --loops=1 --bs=${SIZE[$i]}M --iodepth=1 --numjobs=1 --rw=readwrite\
  > /dev/null

for (( i=0; i<${#NAME[@]}; i++ )); do
  echo
  echo -e "${COLOR[$i]}${LABEL[$i]}:$(color $RESET)"
  printf "<= Read:  "
  fio --loops=$LOOPS --size=${SIZE[$i]}M --filename=$TARGET/.diskmark.tmp --stonewall --ioengine=libaio --direct=1 --zero_buffers=$WRITEZERO --output-format=json \
    --name=${NAME[$i]}Read ${PARAMS[$i]}read \
    > $TARGET/.diskmark.json
  echo "$(${PARSE[$i]}ReadResult "${NAME[$i]}Read")"
  printf "=> Write: "
  fio --loops=$LOOPS --size=${SIZE[$i]}M --filename=$TARGET/.diskmark.tmp --stonewall --ioengine=libaio --direct=1 --zero_buffers=$WRITEZERO --output-format=json \
    --name=${NAME[$i]}Write ${PARAMS[$i]}write \
    > $TARGET/.diskmark.json
  echo "$(${PARSE[$i]}WriteResult "${NAME[$i]}Write")"
done

echo
echo -e "✅ Benchmark $(color $BOLD $GREEN)finished$(color $RESET)."

rm $TARGET/.diskmark.json $TARGET/.diskmark.tmp
