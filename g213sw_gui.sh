#!/bin/bash
# ----------------------------------------------------------------- #
# G213Switcher GUI , july 2018
# ----------------------------------------------------------------- #

mkdir "$HOME/.config"
rulesFile="$HOME/.config/g213switcher_rules.txt"
settingsFile="$HOME/.config/g213switcher_settings.ini"
mode="OFF"
programState="START"

start()
{
	g213switcherl=""
	if [[ "$programState" == "STOP" ]]; then
		g213switcherl="RUN"
	else
		g213switcherl="KILL"
	fi
	
	dialog=$(zenity --width 500 --height 100 --question --title 'G213 LED Switcher' \
	--text "<b>-GUI for G213 LED switcher-</b>\n\nSettings path: $settingsFile\nRules path: $rulesFile\n\nMode: <b>$mode</b>\nStatus 'g213switcher': <b>$programState</b>\n\nVersion 1.0, july 2018\nAuthor: Vid Trtnik" \
	--extra-button 'Add rule' \
	--extra-button 'Delete rule' \
	--ok-label "g213switcher $g213switcherl" \
	--cancel-label 'EXIT' \
	--timeout 0 2>/dev/null)
	rc=$?
	echo "${rc}-${dialog}"
}

windowProcesses()
{
	procList=$(ps -e -o comm= --sort=args)
	list=($(echo "${procList[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
	choice=$(zenity --list --title "Add rule..." --text "Choose process" --column "Name" "${list[@]}" 2>/dev/null)
	echo "$choice"
}

windowEffect()
{
	choice=$(zenity --list --title "Add rule..." --text "Lightning effect" --column "Mode" "Static" "Blinking" "RGB" 2>/dev/null)
	echo "$choice"
}

windowColors()
{
	choice=$(zenity --color-selection 2>/dev/null)
	echo "$choice"
}

windowSpeed()
{
	choice=$(zenity --scale --text "Set lightning effect speed" --min-value=10 --max-value=100 --value=50 --step 10  2>/dev/null);
	echo $choice
}

windowChooseFile()
{
	choice=$(zenity --file-selection --title='Choose file' 2>/dev/null)
	if [[ ! -z "$choice" ]]; then
		choice=$(basename $choice)
	fi
	echo $choice
}

windowEnterName()
{
	choice=$(zenity --entry --title="G213 LED switcher" --text="Enter name" 2>/dev/null)
	echo $choice
}

windowDelete()
{
	RULES=()
	while read r; do
		RULES+=($r)
	done <$rulesFile

	choice=$(zenity --list --title "Delete rule..." --text "Choose rule to delete" --column "Name" "${RULES[@]}" 2>/dev/null)
	
	if [[ -z "$choice" ]]; then
		return 1
	else
		sed -i "/$choice/d" $rulesFile
	fi

	echo "$choice"
}

addRule()
{
	name="$1"
	effect=$(windowEffect)
	if [[ -z "$effect" ]]; then
		return 1
	fi
	
	color="0,0,0"
	if [[ "$effect" != "RGB" ]]; then
		color=$(echo $(windowColors) | tr -d '().argb')
		if [[ -z "$color" ]]; then
			return 1
		fi
	fi
	
	speed=0
	if [[ "$effect" != "Static" ]]; then
		speed=$(windowSpeed)
		if [[ -z "$speed" ]]; then
			return 1
		fi
	fi

	if [[ "$effect" == "Static" ]]; then
		effect=1
	elif [[ "$effect" == "Blinking" ]]; then
		effect=2
	elif [[ "$effect" == "RGB" ]]; then
		effect=3
	else
		efekt=1
	fi
	
	rule="$name,$effect,$color,$speed"
	echo "$rule" >> $rulesFile
}

windowCPU()
{
	mode="RULES"
	if [ ! -f $settingsFile ]; then
		touch "$settingsFile"
		echo "0" > "$settingsFile"
		return 0
	fi

	line=$(head -c 1 $settingsFile)
	if [[ "$line" == "" ]]; then
		echo '0' > $settingsFile
		return 0
	fi

	if [[ "$line" == "1" ]]; then
		echo '0' > $settingsFile
		return 0
	else
		mode="CPUIND"
		echo '1' > $settingsFile
		return 1
	fi
}


windowAddRule()
{
	dialog=$(zenity --width 500 --height 100 --question --title 'G213 LED switcher' \
	--text '-Add new rule-' \
	--extra-button 'Select process' \
	--cancel-label 'CANCEL' \
	--ok-label 'Choose file' \
	--extra-button 'Enter name' \
	--extra-button 'Global' \
	--extra-button "CPU Indicator" \
	--timeout 0 2>/dev/null)
	rc=$?
	echo "${rc}-${dialog}"
}

MAIN()
{
	prog=""
	line=$(head -c 1 $settingsFile)
	if [[ "$line" == "1" ]]; then
		mode="CPUIND"
	elif [[ "$line" == "2" ]]; then
		mode="GLOBAL"
	elif [[ "$line" == "0" ]]; then
		mode="RULES"
	fi
	
	st=$(pgrep g213switcher)
	if [[ "$st" == "" ]]; then
		programState="STOP"
	else
		programState="START"
	fi
	
	ret=$(start)

	if [[ "$ret" == "1-Add rule" ]]; then #Add new rule
		ret=$(windowAddRule)
		if [[ "$ret" == "1-Select process" ]]; then #Select process
			prog=$(windowProcesses)
		elif [[ "$ret" == "0-" ]]; then
			prog=$(windowChooseFile)
		elif [[ "$ret" == "1-Enter name" ]]; then
			prog=$(windowEnterName)
		elif [[ "$ret" == "1-Global" ]]; then
			prog="G"
			echo '2' > $settingsFile #Globalno
			zenity --warning --text="Global mode is active. Only global rules will be active." 2>/dev/null
		elif [[ "$ret" == "1-CPU Indicator" ]]; then
			windowCPU
			cpu=$?
			if [[ "$cpu" -eq 1 ]]; then
				zenity --warning --text="CPU Ind. ON" 2>/dev/null	
			elif [[ "$cpu" -eq 0 ]]; then
				zenity --warning --text="CPU Ind. OFF" 2>/dev/null		
			fi
		fi
	elif [[ "$ret" == "1-Delete rule" ]]; then
		rule="x"
		while [ "$rule" != "" ]; do
			rule=$(windowDelete)
		done
	elif [[ "$ret" == "0-" ]]; then
		if [[ "$programState" == "START" ]]; then
			killall g213switcher > /dev/null
		else
			g213switcher &
		fi
			
	else
		return 1
	fi

	if [[ ! -z "$prog" ]]; then
		addRule "$prog"
	fi

	MAIN
}

MAIN
