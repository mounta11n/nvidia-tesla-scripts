#!/bin/bash

# just set powerlimit
# normally you need root/sudo permission for this
# therefore it's best to let a damon manage this script
#
# here an example for my rtx 3090 ti (GPU0) and tesla p40 (GPU1)

while true; do
  /usr/bin/nvidia-smi -i 0 -pl 300
  /usr/bin/nvidia-smi -i 1 -pl 125
  sleep 60
done
