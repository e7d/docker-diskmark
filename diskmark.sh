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
  echo -e "\r\n\n🛑 The benchmark was $(color $BOLD $RED)interrupted$(color $RESET)."
  if [ ! -z "$2" ]; then
    echo -e "➤ $2"
  fi
  clean
  exit "${EXIT_CODE}"
}
trap 'interrupt $? "The benchmark was aborted before its completion."' HUP INT QUIT KILL TERM

function fail() {
  local EXIT_CODE="${1:-1}"
  echo -e "\r\n\n❌ The benchmark had $(color $BOLD $RED)failed$(color $RESET)."
  if [ ! -z "$2" ]; then
    echo -e "➤ $2"
  fi
  clean
  exit "${EXIT_CODE}"
}
trap 'fail $? "The benchmark failed before its completion."' ERR

function error() {
  local EXIT_CODE="${1:-1}"
  echo -e "\r\n❌ The benchmark encountered an $(color $BOLD $RED)error$(color $RESET)."
  if [ ! -z "$2" ]; then
    echo -e "➤ $2"
  fi
  clean
  exit "${EXIT_CODE}"
}

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
  if (( SIZE > 1024 )); then
    SIZE=$((SIZE / 1024))
    UNIT="T"
  fi
  if (( SIZE > 1024 )); then
    SIZE=$((SIZE / 1024))
    UNIT="P"
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
  COLOR=($(color $NORMAL $YELLOW) $(color $NORMAL $YELLOW) $(color $NORMAL $CYAN) $(color $NORMAL $CYAN))
  BLOCKSIZE=("1M" "1M" "4K" "4K")
  IODEPTH=(8 1 32 1)
  NUMJOBS=(1 1 1 1)
  READWRITE=("" "" "rand" "rand")
  SIZEDIVIDER=(-1 -1 16 32)
}

function loadNVMeProfile() {
  NAME=("SEQ1MQ8T1" "SEQ128KQ32T1" "RND4KQ32T16" "RND4KQ1T1")
  LABEL=("Sequential 1M Q8T1" "Sequential 128K Q32T1" "Random 4K Q32T16" "Random 4K Q1T1")
  COLOR=($(color $NORMAL $YELLOW) $(color $NORMAL $GREEN) $(color $NORMAL $CYAN) $(color $NORMAL $CYAN))
  BLOCKSIZE=("1M" "128K" "4K" "4K")
  IODEPTH=(8 32 32 1)
  NUMJOBS=(1 1 16 1)
  READWRITE=("" "" "rand" "rand")
  SIZEDIVIDER=(-1 -1 16 32)
}

function loadJob() {
  PARAMS=($(echo "$JOB" | perl -nle '/^(RND|SEQ)([0-9]+[KM])Q([0-9]+)T([0-9]+)$/; print "$1 $2 $3 $4"'))
  if [ -z ${PARAMS[0]} ]; then
    error 1 "Invalid job name: $(color $BOLD $WHITE)$JOB$(color $RESET)"
  fi

  case "${PARAMS[0]}" in
    RND)
      READWRITE=("rand")
      READWRITELABEL="Random"
      ;;
    SEQ)
      READWRITE=("")
      READWRITELABEL="Sequential"
      ;;
  esac
  BLOCKSIZE=(${PARAMS[1]})
  IODEPTH=(${PARAMS[2]})
  NUMJOBS=(${PARAMS[3]})

  NAME=($JOB)
  LABEL="$READWRITELABEL $BLOCKSIZE Q${IODEPTH}T${NUMJOBS}"
  COLOR=($(color $NORMAL $MAGENTA))
}

TARGET="${TARGET:-$(pwd)}"
if [ ! -d "$TARGET" ]; then
  ISNEWDIR=1
  mkdir -p "$TARGET"
fi
DRIVELABEL="Drive"
FILESYSTEM=$(df -T "$TARGET" | tail +2 | awk '{print $1}')
FILESYSTEMPARTITION=$(echo $FILESYSTEM | cut -d/ -f3 | cut -d" " -f1)
FILESYSTEMTYPE=$(df -T "$TARGET" | tail +2 | awk '{print $2}')
FILESYSTEMSIZE=$(df -Th "$TARGET" | tail +2 | awk '{print $3}')
ISOVERLAY=0
ISTMPFS=0
ISNVME=0
ISEMMC=0
ISMDADM=0
if [[ "$FILESYSTEMTYPE" == overlay ]]; then
  ISOVERLAY=1
elif [[ "$FILESYSTEMTYPE" == tmpfs ]]; then
  ISTMPFS=1
elif [[ "$FILESYSTEMPARTITION" == mmcblk* ]]; then
  DRIVE=$(echo $FILESYSTEMPARTITION | rev | cut -c 3- | rev)
  ISEMMC=1
elif [[ "$FILESYSTEMPARTITION" == nvme* ]]; then
  DRIVE=$(echo $FILESYSTEMPARTITION | rev | cut -c 3- | rev)
  ISNVME=1
elif [[ "$FILESYSTEMPARTITION" == hd* ]] || [[ "$FILESYSTEMPARTITION" == sd* ]] || [[ "$FILESYSTEMPARTITION" == vd* ]]; then
  DRIVE=$(echo $FILESYSTEMPARTITION | rev | cut -c 2- | rev)
elif [[ "$FILESYSTEMPARTITION" == md* ]]; then
  DRIVE=$FILESYSTEMPARTITION
  ISMDADM=1
else
  DRIVE=""
fi
if [ $ISOVERLAY -eq 1 ]; then
  DRIVENAME="Overlay"
  DRIVE="overlay"
  DRIVESIZE=$FILESYSTEMSIZE
elif [ $ISTMPFS -eq 1 ]; then
  DRIVENAME="RAM"
  DRIVE="tmpfs"
  DRIVESIZE=$(free -h --si | grep Mem: | awk '{print $2}')
elif [ $ISEMMC -eq 1 ]; then
  DEVICE=()
  if [ -f /sys/block/$DRIVE/device/type ]; then
    case "$(cat /sys/block/$DRIVE/device/type)" in
      SD) DEVICE+=("SD Card");;
      *) DEVICE+=();;
    esac
  fi
  [ -f /sys/block/$DRIVE/device/name ] && DEVICE+=($(cat /sys/block/$DRIVE/device/name | sed 's/ *$//g'))
  DRIVENAME=${DEVICE[@]:-"eMMC flash storage"}
  DRIVESIZE=$(fromBytes $(($(cat /sys/block/$DRIVE/size) * 512)))
elif [ $ISMDADM -eq 1 ]; then
  DRIVELABEL="Drives"
  DRIVENAME="mdadm $(cat /sys/block/$DRIVE/md/level)"
  DRIVESIZE=$(fromBytes $(($(cat /sys/block/$DRIVE/size) * 512)))
  DISKS=$(ls /sys/block/$DRIVE/slaves/)
  DRIVEDETAILS="using $(echo $DISKS | wc -w) disks ($(echo $DISKS | sed 's/ /, /g'))"
elif [ -d /sys/block/$DRIVE/device ]; then
  DEVICE=()
  [ -f /sys/block/$DRIVE/device/vendor ] && DEVICE+=($(cat /sys/block/$DRIVE/device/vendor | sed 's/ *$//g'))
  [ -f /sys/block/$DRIVE/device/model ] && DEVICE+=($(cat /sys/block/$DRIVE/device/model | sed 's/ *$//g'))
  DRIVENAME=${DEVICE[@]:-"Unknown drive"}
  DRIVESIZE=$(fromBytes $(($(cat /sys/block/$DRIVE/size) * 512)))
else
  DRIVE="Unknown"
  DRIVENAME="Unknown"
  DRIVESIZE="Unknown"
fi
if [ ! -z $JOB ]; then
  PROFILE="Job \"$JOB\""
  loadJob
else
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
fi
case "$IO" in
  buffered)
    IO="buffered (asynchronous)"
    DIRECT=0
    ;;
  *)
    IO="direct (synchronous)"
    DIRECT=1
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
SIZE="${SIZE:-1G}"
BYTESIZE=$(toBytes $SIZE)
if [ ! -z $LOOPS ]; then
  LIMIT="Loops: $LOOPS"
  LIMIT_OPTION="--loops=$LOOPS"
else
  RUNTIME="${RUNTIME:-5s}"
  LIMIT="Runtime: $RUNTIME"
  LIMIT_OPTION="--time_based --runtime=$RUNTIME"
fi

echo -e "$(color $BOLD $WHITE)Configuration:$(color $RESET)
- Target: $TARGET
  - $DRIVELABEL: $DRIVENAME ($DRIVE, $DRIVESIZE) $DRIVEDETAILS
  - Filesystem: $FILESYSTEMTYPE ($FILESYSTEMPARTITION, $FILESYSTEMSIZE)
- Profile: $PROFILE
  - I/O: $IO
  - Data: $DATA
  - Size: $SIZE
  - $LIMIT

The benchmark is $(color $BOLD $WHITE)running$(color $RESET), please wait..."

fio_benchmark() {
  fio --filename="$TARGET/.diskmark.tmp" \
    --stonewall --ioengine=libaio --direct=$DIRECT --zero_buffers=$WRITEZERO \
    $LIMIT_OPTION --size="$1" \
    --name="$2" --blocksize="$3" --iodepth="$4" --numjobs="$5" --readwrite="$6" \
    --output-format=json >"$TARGET/.diskmark.json"
}

if [ $WARMUP -eq 1 ]; then
  if [ $WRITEZERO -eq 1 ]; then
    FILESOURCE=/dev/zero
  else
    FILESOURCE=/dev/urandom
  fi
  dd if="$FILESOURCE" of="$TARGET/.diskmark.tmp" bs="$BYTESIZE" count=1 oflag=direct
fi

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

echo -e "\n✅ The benchmark is $(color $BOLD $GREEN)finished$(color $RESET)."

clean
