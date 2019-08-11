#!/bin/bash
# ----------------------------------------------------------------- #
# G213Switcher , july 2018
# ----------------------------------------------------------------- #

if [[ "$(pidof -x $(basename $0) -o %PPID)" ]]; then 
	echo "Already running, exit..."
	exit 3; 
fi

settingsFile="$HOME/.config/g213switcher_settings.ini"
rulesFile="$HOME/.config/g213switcher_rules.txt"
rulesFile_md5_prev=""
RULES=()

HID_NAME='HID_NAME=Logitech Gaming Keyboard G213'
HID_ST=-1

COMMAND1="11 ff 0c 0e 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00" # ???
COMMAND2="11 ff 0c 3e 00 01 ab cd ef 02 00 00 00 00 00 00 00 00 00 00"

GREEN="11 ff 0c 3e 00 01 00 ff 00 02 00 00 00 00 00 00 00 00 00 00"
YELLOW="11 ff 0c 3e 00 01 ff ff 00 02 00 00 00 00 00 00 00 00 00 00"
RED="11 ff 0c 3e 00 01 ff 00 00 02 00 00 00 00 00 00 00 00 00 00"
RED_BR="11 ff 0c 3e 00 02 ff 00 00 03 e8 00 64 00 00 00 00 00 00 00"

find_device()
{
	local HID_NAME="$1"
	local HID_ST=-1

	NUM_OF_HID=$(find /sys/class/hidraw 2>/dev/null | wc -l 2>/dev/null)
	#echo "NUM_OF_HID: $NUM_OF_HID"
	
	C=1
	for (( i=0; i<$NUM_OF_HID-1; i++ )); do
		TMP_HID_NAME=$(sed -n '3p' "/sys/class/hidraw/hidraw$i/device/uevent" 2>/dev/null)

		if [[ "$TMP_HID_NAME" == "$HID_NAME" ]] && [ -e /dev/hidraw$i ]; then
			#echo "$i:OK"
			HID_ST=$i
			if [[ "$C" -eq 1 ]]; then
				break
			fi
		fi
	done

	echo $HID_ST
}

wait_for_device()
{
	HID_ST=-1
	while [ $HID_ST -lt 0 ]; do
		HID_ST=$(find_device "$HID_NAME")
		if [[ "$HID_ST" -lt 0 ]]; then
			sleep $1
		fi
	done

	if [[ "$2" -eq 0 ]]; then
		notify-send --urgency=low --expire-time=1000 -i keyboard "'Logitech G213 Prodigy' found, resuming..."	
	else
		notify-send --urgency=low --expire-time=1000 -i keyboard "Logitech G213 Auto LED Switcher ON"
	fi
}

reloadDefaultRules()
{
	echo "vlc,1,255,255,255,0"
	     "nautilus,1,255,255,0,0" > $rulesFile
}

detectRulesChange()
{	
	R=1
	rulesFile_md5=$(md5sum $rulesFile)
	#echo "md5 $rulesFile_md5"
	if [[ "$rulesFile_md5" == "$rulesFile_md5_prev" ]]; then
		R=0	
	else
		R=1
	fi

	rulesFile_md5_prev=$rulesFile_md5
	return $R
}

reloadSettings()
{
	if [ ! -f $settingsFile ]; then
		#echo "Creating config file -$settingsFile-"
		touch "$settingsFile"
		echo '0' > "$settingsFile"
	fi
	line=$(head -c 1 $settingsFile)
	if [[ "$line" == '1' ]]; then
		return 1
	fi
	if [[ "$line" == '2' ]]; then
		return 2
	fi
	return 0
}

reloadRules()
{
	RULES=()
	while read r; do
		RULES+=($r)
	done <$rulesFile
}

checkRules()
{
	i=0
	for r in "${RULES[@]}"; do
		if [[ "$r" == *"$1"* ]]; then
			echo "$i"
			break
		fi
	((i++))
	done
	
	echo "-1"
}

focusedWin_GetPID()
{
	PID=$(xprop -id $(xprop -root | awk '/_NET_ACTIVE_WINDOW\(WINDOW\)/{print $NF}') | awk '/_NET_WM_PID\(CARDINAL\)/{print $NF}')

	echo $PID
}

focusedWin_GetEXE()
{
	PID=$(focusedWin_GetPID)
	EXE=$(ps -p $PID -o comm=)

	echo $EXE
}

sendCommands()
{
	command1=""
	command2=""

	arr=()
	IFS=',' read -r -a arr <<< "${RULES[$1]}"

	#for el in "${arr[@]}"; do
	#	echo "$el"
	#done

	EFFECT="${arr[1]}"
	R="${arr[2]}"
	G="${arr[3]}"
	B="${arr[4]}"
	Speed="${arr[5]}"
		
	speed=$(($Speed - 100))
	if [[ "$speed" -lt 0 ]]; then
		speed=$(($speed * -1))
	fi
	speed=$(($(($speed * 190)) + 1000))
	if [[ "$speed" -gt 20000 ]]; then
		speed=20000
	fi
	
	speedVal_p1=$(($speed % 256))
	speedVal_p2=$(($(($speed - $speedVal_p1)) >> 8))

	com=()
	IFS=' ' read -r -a com <<< "$COMMAND2"
	#printf -v res "%02X" "10"
	com[6]=$(printf "%02x" "$R")
	com[7]=$(printf "%02x" "$G")
	com[8]=$(printf "%02x" "$B")

	case $EFFECT in
	"1")
		com[5]="01"
		com[9]="02"
		com[10]="00"
		com[11]="00"
		com[12]="00"
		com[13]="00"
		;;

	"2")
		com[5]="02"
		com[9]=$(printf "%02x" "$speedVal_p2")
		com[10]=$(printf "%02x" "$speedVal_p1")
		com[11]="00"
		com[12]="64"
		com[13]="00"
		;;

	"3")
		com[5]="03"
		com[9]="00"
		com[10]="00"
		com[11]=$(printf "%02x" "$speedVal_p2")
		com[12]=$(printf "%02x" "$speedVal_p1")
		com[13]="64"
		;;

	*)
		echo "ERROR: Wrong argument!"
		;;
	esac
	
	command2=$(IFS=' '; echo "${com[*]}")

	com=()
	IFS=' ' read -r -a com <<< "$COMMAND1"
	command1=$(IFS=' '; echo "${com[*]}")

	#echo "$command1"
	#echo "$command2"

	sendToDevice "$command1" "$command2"
}

sendToDevice()
{
	if [ -e /dev/hidraw$HID_ST ]; then
		echo "$1" | xxd -r -p | tee /dev/hidraw$HID_ST > /dev/null
	else
		notify-send --urgency=low --expire-time=1000 -i dialog-error "'Logitech G502 Spectrum' disconected, waiting..."
		wait_for_device 30 0
	fi

	sleep 0.075

	if [ -e /dev/hidraw$HID_ST ]; then
		echo "$2" | xxd -r -p | tee /dev/hidraw$HID_ST > /dev/null
	else
		notify-send --urgency=low --expire-time=1000 -i dialog-error "'Logitech G502 Spectrum' disconected, waiting"
		wait_for_device 30 0
	fi
}

CPUIndicatorMode()
{
	sendToDevice "$COMMAND1" "$GREEN"
	RET=1
	I=0
	while [ "$RET" -eq 1 ]; do
		if [[ "$I" -gt 15 ]]; then
			reloadSettings
			RET=$?
			I=0
			continue
		fi
		THREADS=$( grep -c ^processor /proc/cpuinfo ) 
		PR=$( top -b -n 1 | sed -n '8,18p' | awk '{print $9}' | cut -d',' -f1 )
		PERCENT=0
while read -r st; do
	((PERCENT+=st))
done <<< "$PR"

USAGE=$(( PERCENT / THREADS ))

if [ "$USAGE" -ge 0 ] && [ "$USAGE" -le 24 ]; then
STATUS=0

elif [ "$USAGE" -ge 25 ] && [ "$USAGE" -le 50 ]; then
STATUS=1

elif [ "$USAGE" -ge 51 ] && [ "$USAGE" -le 75 ]; then
STATUS=2

else #%CPU > 76
STATUS=3
fi

if [ "$P_STATUS" != "$STATUS" ]; then
	case $STATUS in
	0)
		sendToDevice "$COMMAND1" "$GREEN"
		;;

	1)
		sendToDevice "$COMMAND1" "$YELLOW"
		;;

	2)
		sendToDevice "$COMMAND1" "$RED"
		;;

	3)
		sendToDevice "$COMMAND1" "$RED_BR"
		;;

	*)
		sendToDevice "$COMMAND1" "$GREEN"
		;;
	esac
fi
P_STATUS=$STATUS
((I++))
sleep 1
done	
}

GlobalMode()
{
	sendToDevice "$COMMAND1" "$GREEN"
	RET=2
	I=0
	globalRule=$(checkRules "G")
	if [[ "$globalRule" == "-1" ]]; then
		echo ERROR - No global rule.
		sendToDevice "$COMMAND1" "$RED"
		return 1
	fi
	while [ "$RET" -eq 2 ]; do
		if [[ "$I" -gt 15 ]]; then
			reloadSettings
			RET=$?
			detectRulesChange
			change=$?
			if [[ "$change" -eq 1 ]]; then
				reloadRules
			fi
			globalRule=$(checkRules "G")
			if [[ "$globalRule" == "-1" ]]; then
				echo ERROR - No global rule.
				sendToDevice "$COMMAND1" "$RED"
				return 1
			fi

			I=0
			continue
		fi
	
	sendCommands $globalRule
	((I++))
	sleep 1
	done
}

MAIN()
{
	wait_for_device 30 1
	prevEXE=""
	watcher=0

	reloadRules
	reloadSettings
	setting=$?
	if [[ "$setting" -eq 1 ]]; then
		CPUIndicatorMode # mode=CPUIND
	fi
	if [[ "$setting" -eq 2 ]]; then
		echo GlobalMode
		GlobalMode # mode=GLOBAL
	fi
	
	while true; do
		currEXE=$(focusedWin_GetEXE)
		if [[ "$prevEXE" != "$currEXE" ]]; then
			RET=$(checkRules "$currEXE")
			if [[ "$RET" != "-1" ]]; then
				sendCommands $RET 
			fi
		fi
		prevEXE=$currEXE

		if [[ "$watcher" -gt 15 ]]; then
			reloadSettings
			setting=$?
			if [[ "$setting" -eq 1 ]]; then
				CPUIndicatorMode
			fi
			if [[ "$setting" -eq 2 ]]; then
				GlobalMode
			fi
			detectRulesChange
			change=$?
			if [[ "$change" -eq 1 ]]; then
				reloadRules
			fi
			watcher=0
		fi
			
		((watcher++))
		sleep 1
	done
}

MAIN
