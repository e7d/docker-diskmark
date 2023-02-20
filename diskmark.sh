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
  echo
  echo -e "❌ Benchmark $(color $BOLD $RED)failed$(color $RESET)."
  if [ ! -z "$2" ]; then
    echo "> $2"
  fi
  exit "${EXIT_CODE}"
}

trap 'finally $? "The benchmark was aborted before its completion."' INT

function toBytes() {
  local SIZE=$1
  local UNIT=$(echo $SIZE | sed 's/[0-9]//g')
  local NUMBER=$(echo $SIZE | sed 's/[a-zA-Z]//g')
  case $UNIT in
    G | g)
      echo $((NUMBER*1024*1024*1024))
      ;;
    M | m)
      echo $((NUMBER*1024*1024))
      ;;
    K | k)
      echo $((NUMBER*1024))
      ;;
    *)
      echo $NUMBER
      ;;
  esac
}

# convert bytes to human readable format
function fromBytes() {
  local SIZE=$1
  local UNIT=""
  if [ $SIZE -gt 1024 ]; then
    SIZE=$((SIZE/1024))
    UNIT="K"
  fi
  if [ $SIZE -gt 1024 ]; then
    SIZE=$((SIZE/1024))
    UNIT="M"
  fi
  if [ $SIZE -gt 1024 ]; then
    SIZE=$((SIZE/1024))
    UNIT="G"
  fi
  echo "${SIZE}${UNIT}"
}

function parseReadResult() {
  echo "$(($(cat "$TARGET/.diskmark.json" | grep -A15 '"name" : "'"$1"'"' | grep bw_bytes | cut -d: -f2 | sed s:,::g)/1024/1024)) MB/s, $(cat "$TARGET/.diskmark.json" | grep -A15 '"name" : "'"$1"'"' | grep -m1 iops | cut -d: -f2 | cut -d. -f1 | sed 's: ::g') IO/s"
}

function parseWriteResult() {
  echo "$(($(cat "$TARGET/.diskmark.json" | grep -A80 '"name" : "'"$1"'"' | grep bw_bytes | sed '2!d' | cut -d: -f2 | sed s:,::g)/1024/1024)) MB/s, $(cat "$TARGET/.diskmark.json" | grep -A80 '"name" : "'"$1"'"' | grep iops | sed '7!d' | cut -d: -f2 | cut -d. -f1 | sed 's: ::g') IO/s"
}

function parseRandomReadResult() {
  echo "$(($(cat "$TARGET/.diskmark.json" | grep -A15 '"name" : "'"$1"'"' | grep bw_bytes | sed 's/        "bw_bytes" : //g' | sed 's:,::g' | awk '{ SUM += $1} END { printf "%.0f", SUM }')/1024/1024)) MB/s, $(cat "$TARGET/.diskmark.json" | grep -A15 '"name" : "'"$1"'"' | grep iops | sed 's/        "iops" : //g' | sed 's:,::g' | awk '{ SUM += $1} END { printf "%.0f", SUM }' | cut -d. -f1) IO/s"
}

function parseRandomWriteResult() {
  echo "$(($(cat "$TARGET/.diskmark.json" | grep -A80 '"name" : "'"$1"'"' | grep bw_bytes | sed 's/        "bw_bytes" : //g' | sed 's:,::g' | awk '{ SUM += $1} END { printf "%.0f", SUM }')/1024/1024)) MB/s, $(cat "$TARGET/.diskmark.json" | grep -A80 '"name" : "'"$1"'"' | grep iops | sed 's/        "iops" : //g' | sed 's:,::g' | awk '{ SUM += $1} END { printf "%.0f", SUM }' | cut -d. -f1) IO/s"
}

function loadDefaultProfile() {
  NAME[0]="SEQ1MQ8T1"
  LABEL[0]="Sequential 1M Q8T1"
  BLOCKSIZE[0]="1M"
  IODEPTH[0]=8
  NUMJOBS[0]=1
  READWRITE[0]=""
  COLOR[0]=$(color $NORMAL $YELLOW)
  TESTSIZE[0]=$BYTESIZE

  NAME[1]="SEQ1MQ1T1"
  LABEL[1]="Sequential 1M Q1T1"
  BLOCKSIZE[1]="1M"
  IODEPTH[1]=1
  NUMJOBS[1]=1
  READWRITE[1]=""
  COLOR[1]=$(color $NORMAL $YELLOW)
  TESTSIZE[1]=$BYTESIZE

  NAME[2]="RND4KQ32T1"
  LABEL[2]="Random 4K Q32T1"
  BLOCKSIZE[2]="4k"
  IODEPTH[2]=32
  NUMJOBS[2]=1
  READWRITE[2]="rand"
  COLOR[2]=$(color $NORMAL $CYAN)
  TESTSIZE[2]=$(($BYTESIZE/16))

  NAME[3]="RND4KQ1T1"
  LABEL[3]="Random 4K Q1T1"
  BLOCKSIZE[3]="4k"
  IODEPTH[3]=1
  NUMJOBS[3]=1
  READWRITE[3]="rand"
  COLOR[3]=$(color $NORMAL $CYAN)
  TESTSIZE[3]=$(($BYTESIZE/32))
}

function loadNVMeProfile() {
  NAME[0]="SEQ1MQ8T1"
  LABEL[0]="Sequential 1M Q8T1"
  BLOCKSIZE[0]="1M"
  IODEPTH[0]=8
  NUMJOBS[0]=1
  READWRITE[0]=""
  COLOR[0]=$(color $NORMAL $YELLOW)
  TESTSIZE[0]=$BYTESIZE

  NAME[1]="SEQ128KQ32T1"
  LABEL[1]="Sequential 128K Q32T1"
  BLOCKSIZE[1]="128k"
  IODEPTH[1]=32
  NUMJOBS[1]=1
  READWRITE[1]=""
  COLOR[1]=$(color $NORMAL $GREEN)
  TESTSIZE[1]=$BYTESIZE

  NAME[2]="RND4KQ32T16"
  LABEL[2]="Random 4K Q32T16"
  BLOCKSIZE[2]="4k"
  IODEPTH[2]=32
  NUMJOBS[2]=16
  READWRITE[2]="rand"
  COLOR[2]=$(color $NORMAL $CYAN)
  TESTSIZE[2]=$(($BYTESIZE/16))

  NAME[3]="RND4KQ1T1"
  LABEL[3]="Random 4K Q1T1"
  BLOCKSIZE[3]="4k"
  IODEPTH[3]=1
  NUMJOBS[3]=1
  READWRITE[3]="rand"
  COLOR[3]=$(color $NORMAL $CYAN)
  TESTSIZE[3]=$(($BYTESIZE/32))
}

TARGET="${TARGET:-/disk}"
if [ ! -d "$TARGET" ]; then
  ISNEWDIR=1
  mkdir -p "$TARGET"
fi
PARTITION=$(df "$TARGET" | grep /dev | cut -d/ -f3 | cut -d" " -f1)
ISNVME=0
if [ -z "$PARTITION" ]; then
  DRIVE=""
elif [[ "$PARTITION" == nvme* ]]; then
  DRIVE=$(echo $PARTITION | rev | cut -c 3- | rev)
  ISNVME=1
else
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
BYTESIZE=$(toBytes $SIZE)
case "$PROFILE" in
  default)
    loadDefaultProfile
    ;;
  nvme)
    loadNVMeProfile
    ;;
  *)
    if [ $ISNVME -eq 1 ]; then
      PROFILE="auto (nvme)"
      loadNVMeProfile
    else
      PROFILE="auto (default)"
      loadDefaultProfile
    fi
    ;;
esac
case "$DATA" in
  zero | 0 | 0x00)
    WRITEZERO=1
    ;;
  *)
    WRITEZERO=0
    ;;
esac

echo -e "$(color $BOLD $WHITE)Configuration:$(color $RESET)
- Target: $TARGET
- Drive: $DRIVEMODEL ($DRIVE, $DRIVESIZE)
- Profile: $PROFILE
- Data: $DATA
- Size: $SIZE
- Loops: $LOOPS

Benchmark is $(color $BOLD $WHITE)running$(color $RESET), please wait..."

fio --loops=$LOOPS --size=$BYTESIZE --filename="$TARGET/.diskmark.tmp" --stonewall --ioengine=libaio --direct=1 --zero_buffers=$WRITEZERO --output-format=json \
  --name=Bufread --loops=1 --blocksize=$BYTESIZE --iodepth=1 --numjobs=1 --readwrite=readwrite\
  > /dev/null

for (( i=0; i<${#NAME[@]}; i++ )); do
  case "${READWRITE[$i]}" in
    rand) PARSE="parseRandom" ;;
    *) PARSE="parse" ;;
  esac

  echo
  echo -e "${COLOR[$i]}${LABEL[$i]}:$(color $RESET)"
  printf "<= Read:  "
  fio --loops=$LOOPS --size=${TESTSIZE[$i]} --filename="$TARGET/.diskmark.tmp" --stonewall --ioengine=libaio --direct=1 --zero_buffers=$WRITEZERO --output-format=json \
    --name=${NAME[$i]}Read --blocksize=${BLOCKSIZE[$i]} --iodepth=${IODEPTH[$i]} --numjobs=${NUMJOBS[$i]} --readwrite=${READWRITE[$i]}read \
    > "$TARGET/.diskmark.json"
  echo "$(${PARSE}ReadResult "${NAME[$i]}Read")"
  printf "=> Write: "
  fio --loops=$LOOPS --size=${TESTSIZE[$i]} --filename="$TARGET/.diskmark.tmp" --stonewall --ioengine=libaio --direct=1 --zero_buffers=$WRITEZERO --output-format=json \
    --name=${NAME[$i]}Write --blocksize=${BLOCKSIZE[$i]} --iodepth=${IODEPTH[$i]} --numjobs=${NUMJOBS[$i]} --readwrite=${READWRITE[$i]}write \
    > "$TARGET/.diskmark.json"
  echo "$(${PARSE}WriteResult "${NAME[$i]}Write")"
done

echo
echo -e "✅ Benchmark $(color $BOLD $GREEN)finished$(color $RESET)."

if [ ! -z $ISNEWDIR ]; then
  rm -rf "$TARGET"
else
  rm "$TARGET/.diskmark.json" "$TARGET/.diskmark.tmp"
fi
