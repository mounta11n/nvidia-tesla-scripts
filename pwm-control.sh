#!/bin/bash

# Make sure to correctly assign the fans first
#
# DO NOT MANIPULATE A FAN YOU ARE UNSURE ABOUT
#
# Here is an example:
#
# pwm6 case front, left & middle
# pwm8 case front, right
# pwm7 p40 blower
# pwm4 p40 exhaust
# pwm5 RAM fan
# pwm3 case rear, left & middle
# pwm2 case rear, right
# pwm1 unsure, probably CPU water cooling? DO NOT MANIPULATE IF UNSURE
#
# There are many debates about whether one should create positive or negative
# air pressure inside a computer case. If I understand it correctly, if the case
# is not nearly perfectly sealed, it's better to create positive air pressure.
# The nice side effect is that with positive pressure, less dust accumulates
# inside the case. Ultimately, I think it doesn't make too much of a difference
# and might just be nitpicking.
#
# I personally prefer the positive pressure, therefore I choose:
# All three front fans, PWM6 and PWM8
# Two of the three rear fans, PWM3
# And of course the P40 fan(s), PWM4 and PWM7
# => PWM{3,4,6,7,8}
#
# One more IMPORTANT thing is to make sure you pick the right path.
# In my case it is under hwmon5, but it could be hwmon4 or something else as well

LOGFILE="/var/log/p40-temp-pwm.txt"
MAX_LOG_SIZE=$((10 * 1024 * 1024))  # 10 MB in Bytes
LOG_INTERVAL=60  # log every 60 rounds
counter=0
last_temp=0
last_speed=0

# check and rotate the log
check_and_rotate_log() {
    if [ -f "$LOGFILE" ] && [ $(stat -c%s "$LOGFILE") -gt $MAX_LOG_SIZE ]; then
        mv "$LOGFILE" "${LOGFILE}.old"
        touch "$LOGFILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Logfile rotate" >> $LOGFILE
    fi
}

# check & disable auto-configuration
check_pwm_enable() {
    for pwm in /sys/class/hwmon/hwmon5/pwm{3,4,6,7,8}_enable; do # CHECK YOUR HWMONXX PATH
        if [ "$(cat $pwm)" != "1" ]; then
            echo 1 > $pwm
            echo "$(date '+%Y-%m-%d %H:%M:%S') - $pwm was reset (1)" >> $LOGFILE
        fi
    done
}

# simple logging function
log_if_changed() {
    local temp=$1
    local speed=$2
    if [ $temp -ne $last_temp ] || [ $speed -ne $last_speed ]; then
        log_status $temp $speed
        last_temp=$temp
        last_speed=$speed
    fi
}

# decide which fans you want to control, for example case fans could act as support
set_fan_speed() {
    local speed=$1
    for pwm in /sys/class/hwmon/hwmon5/pwm{3,4,6,7,8}; do # CHECK YOUR HWMONXX PATH
        echo $speed > $pwm
    done
}

# now put everything together. the main logic
while true; do
    check_and_rotate_log

    # query the temperatur of the gpu
    # note. if you have multiple gpus, make sure to set the correct id,
    # either as per pci_bus_id (0,1,.. etc)
    # or the more recommended way is the uuid since this won't change
    # you can query the uuid with nvidia-smi -L, here are two examples:

    #temp=$(nvidia-smi --query-gpu=temperature.gpu --id=0 --format=csv,noheader,nounits | tail -n 1)
    # or
    temp=$(nvidia-smi --query-gpu=temperature.gpu --id=GPU-1ab234cd-e567-f891-2ab3-4c567d891e23 --format=csv,noheader,nounits | tail -n 1)

    # calculate exponential increase
    n=2
    if [ $temp -lt 35 ]; then
        speed=50
    elif [ $temp -ge 35 ] && [ $temp -le 65 ]; then
        speed=$(echo "50 + (205 *(($temp - 35) / 30)^$n)" | bc -l)
        speed=${speed%.*} # convert to intg*
    else
        speed=255
    fi

    # ensure speed within a range
    if [ $speed -lt 50 ]; then
        speed=50
    elif [ $speed -gt 255 ]; then
        speed=255
    fi

    check_pwm_enable
    set_fan_speed $speed
    log_if_changed $temp $speed
    counter=$((counter + 1))
    if [ $counter -ge $LOG_INTERVAL ]; then
        echo "$LOG_INTERVAL seconds log" >> $LOGFILE
        counter=0
    fi
    sleep 1

    # Debug
    #echo "echo"
    #echo "$counter"
done

