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

function clean() {
  [[ -z $TARGET ]] && return
  if [[ -n $ISNEWDIR ]]; then
    rm -rf "$TARGET"
  else
    rm -f "$TARGET"/.diskmark.{json,tmp}
  fi
}

function interrupt() {
  local EXIT_CODE="${1:-0}"
  echo -e "\r\n\n🛑 Benchmark $(color $BOLD $RED)interrupted$(color $RESET)."
  if [ ! -z "$2" ]; then
    echo "➤ $2"
  fi
  clean
  exit "${EXIT_CODE}"
}
trap 'interrupt $? "The benchmark was aborted before its completion."' HUP INT QUIT KILL TERM

function error() {
  local EXIT_CODE="${1:-0}"
  echo -e "\r\n\n❌ Benchmark $(color $BOLD $RED)failed$(color $RESET)."
  if [ ! -z "$2" ]; then
    echo "➤ $2"
  fi
  clean
  exit "${EXIT_CODE}"
}
trap 'error $? "The benchmark failed before its completion."' ERR

function toBytes() {
  local SIZE=$1
  local UNIT=${SIZE//[0-9]/}
  local NUMBER=${SIZE//[a-zA-Z]/}
  case $UNIT in
    T|t) echo $((NUMBER * 1024 * 1024 * 1024 * 1024));;
    G|g) echo $((NUMBER * 1024 * 1024 * 1024));;
    M|m) echo $((NUMBER * 1024 * 1024));;
    K|k) echo $((NUMBER * 1024));;
    *) echo $NUMBER;;
  esac
}

function fromBytes() {
  local SIZE=$1
  local UNIT=""
  if (( SIZE > 1024 )); then
    SIZE=$((SIZE / 1024))
    UNIT="K"
  fi
  if (( SIZE > 1024 )); then
    SIZE=$((SIZE / 1024))
    UNIT="M"
  fi
  if (( SIZE > 1024 )); then
    SIZE=$((SIZE / 1024))
    UNIT="G"
  fi
  echo "${SIZE}${UNIT}"
}

function parseResult() {
  local bandwidth=$(cat "$TARGET/.diskmark.json" | grep -A"$2" '"name" : "'"$1"'"' | grep "$3" | sed 's/        "'"$3"'" : //g' | sed 's:,::g' | awk '{ SUM += $1} END { printf "%.0f", SUM }')
  local throughput=$(cat "$TARGET/.diskmark.json" | grep -A"$2" '"name" : "'"$1"'"' | grep "$4" | sed 's/        "'"$4"'" : //g' | sed 's:,::g' | awk '{ SUM += $1} END { printf "%.0f", SUM }' | cut -d. -f1)
  echo "$(($bandwidth / 1024 / 1024)) MB/s, $throughput IO/s"
}

function parseReadResult() {
  parseResult "$1" 15 bw_bytes iops
}

function parseWriteResult() {
  parseResult "$1" 80 bw_bytes iops
}


function parseRandomReadResult() {
  parseResult "$1" 15 bw_bytes iops
}

function parseRandomWriteResult() {
  parseResult "$1" 80 bw_bytes iops
}

function loadDefaultProfile() {
  NAME=("SEQ1MQ8T1" "SEQ1MQ1T1" "RND4KQ32T1" "RND4KQ1T1")
  LABEL=("Sequential 1M Q8T1" "Sequential 1M Q1T1" "Random 4K Q32T1" "Random 4K Q1T1")
  BLOCKSIZE=("1M" "1M" "4k" "4k")
  IODEPTH=(8 1 32 1)
  NUMJOBS=(1 1 1 1)
  READWRITE=("" "" "rand" "rand")
  COLOR=($(color $NORMAL $YELLOW) $(color $NORMAL $YELLOW) $(color $NORMAL $CYAN) $(color $NORMAL $CYAN))
  SIZEDIVIDER=(-1 -1 16 32)
}

function loadNVMeProfile() {
  NAME=("SEQ1MQ8T1" "SEQ128KQ32T1" "RND4KQ32T16" "RND4KQ1T1")
  LABEL=("Sequential 1M Q8T1" "Sequential 128K Q32T1" "Random 4K Q32T16" "Random 4K Q1T1")
  BLOCKSIZE=("1M" "128k" "4k" "4k")
  IODEPTH=(8 32 32 1)
  NUMJOBS=(1 1 16 1)
  READWRITE=("" "" "rand" "rand")
  COLOR=($(color $NORMAL $YELLOW) $(color $NORMAL $GREEN) $(color $NORMAL $CYAN) $(color $NORMAL $CYAN))
  SIZEDIVIDER=(-1 -1 16 32)
}

TARGET="${TARGET:-$(pwd)}"
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
  DRIVESIZE=$(($(cat /sys/block/$DRIVE/size) * 512 / 1024 / 1024 / 1024))GB
fi
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
    DATA="zero (0x00)"
    WRITEZERO=1
    ;;
  *)
    DATA="random"
    WRITEZERO=0
    ;;
esac
LOOPS="${LOOPS:-5}"
SIZE="${SIZE:-1G}"
BYTESIZE=$(toBytes $SIZE)

echo -e "$(color $BOLD $WHITE)Configuration:$(color $RESET)
- Target: $TARGET
- Drive: $DRIVEMODEL ($DRIVE, $DRIVESIZE)
- Profile: $PROFILE
- Data: $DATA
- Loops: $LOOPS
- Size: $SIZE

Benchmark is $(color $BOLD $WHITE)running$(color $RESET), please wait..."

fio_benchmark() {
  fio --loops="$LOOPS" --size="$1" --filename="$TARGET/.diskmark.tmp" --stonewall --ioengine=libaio --direct=1 --zero_buffers="$WRITEZERO" --output-format=json \
    --name="$2" --blocksize="$3" --iodepth="$4" --numjobs="$5" --readwrite="$6" >"$TARGET/.diskmark.json"
}

fio_benchmark "$BYTESIZE" Bufread "$BYTESIZE" 1 1 readwrite >/dev/null

for ((i = 0; i < ${#NAME[@]}; i++)); do
  TESTSIZE=$((${BYTESIZE} / ${SIZEDIVIDER[$i]:-1}))
  case "${READWRITE[$i]}" in
    rand) PARSE="parseRandom" ;;
    *) PARSE="parse" ;;
  esac

  echo
  echo -e "${COLOR[$i]}${LABEL[$i]}:$(color $RESET)"
  printf "<= Read:  "
  fio_benchmark "$TESTSIZE" "${NAME[$i]}Read" "${BLOCKSIZE[$i]}" "${IODEPTH[$i]}" "${NUMJOBS[$i]}" "${READWRITE[$i]}read"
  echo "$(${PARSE}ReadResult "${NAME[$i]}Read")"
  printf "=> Write: "
  fio_benchmark "$TESTSIZE" "${NAME[$i]}Write" "${BLOCKSIZE[$i]}" "${IODEPTH[$i]}" "${NUMJOBS[$i]}" "${READWRITE[$i]}write"
  echo "$(${PARSE}WriteResult "${NAME[$i]}Write")"
done

echo -e "\n✅ Benchmark $(color $BOLD $GREEN)finished$(color $RESET)."

clean
