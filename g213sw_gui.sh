#!/bin/bash
# ----------------------------------------------------------------- #
# G213Switcher GUI , july 2018
# ----------------------------------------------------------------- #

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

	dialog=$(zenity --question --title 'G213 Auto LED preklopnik' \
	--text "-Nastavitve za G213 Auto LED preklopnik-\nPot do nastavitev: $settingsFile\nPot do pravil: $rulesFile\n\nNacin delovanja: $mode\nStanje 'g213switcher': $programState\n\nVid Trtnik, julij 2018\nUbuntu 16.04" \
	--extra-button 'Dodaj pravilo' \
	--extra-button 'Brisi pravila' \
	--ok-label "g213switcher $g213switcherl" \
	--cancel-label 'IZHOD' \
	--timeout 0 2>/dev/null)
	rc=$?
	echo "${rc}-${dialog}"
}

oknoProcesi()
{
	seznamProcesov=$(ps -e -o comm= --sort=args)
	seznam=($(echo "${seznamProcesov[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
	izbira=$(zenity --list --title "Dodajanje pravila..." --text "Izberi proces" --column "Ime" "${seznam[@]}" 2>/dev/null)
	echo "$izbira"
}

oknoEfekt()
{
	izbira=$(zenity --list --title "Dodajanje pravila..." --text "Izberi nacin osvetlitve" --column "Nacin" "Staticno" "Utripanje" "RGB_Krog" 2>/dev/null)
	echo "$izbira"
}

oknoBarva()
{
	izbira=$(zenity --color-selection 2>/dev/null)
	echo "$izbira"
}

oknoHitrost()
{
	izbira=$(zenity --scale --text "Izberi hitrost svetlobnega učinka" --min-value=10 --max-value=100 --value=50 --step 10  2>/dev/null);
	echo $izbira
}

oknoIzberiDat()
{
	izbira=$(zenity --file-selection --title='Izberi datoteko' 2>/dev/null)
	if [[ ! -z "$izbira" ]]; then
		izbira=$(basename $izbira)
	fi
	echo $izbira
}

oknoVnesiIme()
{
	izbira=$(zenity --entry --title="G213 Auto LED preklopnik" --text="Vnesi ime" 2>/dev/null)
	echo $izbira
}

oknoBrisi()
{
	RULES=()
	while read r; do
		RULES+=($r)
	done <$rulesFile

	izbira=$(zenity --list --title "Brisanje pravil..." --text "Izberi pravilo za izbris" --column "Ime" "${RULES[@]}" 2>/dev/null)
	
	if [[ -z "$izbira" ]]; then
		return 1
	else
		sed -i "/$izbira/d" $rulesFile
	fi

	echo "$izbira"
}

dodajPravilo()
{
	ime="$1"
	efekt=$(oknoEfekt)
	if [[ -z "$efekt" ]]; then
		return 1
	fi
	
	barva="0,0,0"
	if [[ "$efekt" != "RGB_Krog" ]]; then
		barva=$(echo $(oknoBarva) | tr -d '().argb')
		if [[ -z "$barva" ]]; then
			return 1
		fi
	fi
	
	hitrost=0
	if [[ "$efekt" != "Staticno" ]]; then
		hitrost=$(oknoHitrost)
		if [[ -z "$hitrost" ]]; then
			return 1
		fi
	fi

	if [[ "$efekt" == "Staticno" ]]; then
		efekt=1
	elif [[ "$efekt" == "Utripanje" ]]; then
		efekt=2
	elif [[ "$efekt" == "RGB_Krog" ]]; then
		efekt=3
	else
		efekt=1
	fi

	#echo "ime: $ime"
	#echo "efekt: $efekt"
	#echo "barva: $barva"
	#echo "hitrost: $hitrost"
	
	pravilo="$ime,$efekt,$barva,$hitrost"
	echo "$pravilo" >> $rulesFile
}

oknoCPU()
{
	mode="PRAVILA"
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


oknoDodajPravilo()
{
	dialog=$(zenity --question --title 'G213 Auto LED preklopnik' \
	--text '-Dodajanje novega pravila-' \
	--extra-button 'Izberi med procesi' \
	--cancel-label 'NAZAJ' \
	--ok-label 'Izberi datoteko' \
	--extra-button 'Vnesi ime' \
	--extra-button 'Globalno' \
	--extra-button "CPU Indikator" \
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
		mode="PRAVILA"
	fi
	
	st=$(pgrep g213switcher)
	if [[ "$st" == "" ]]; then
		programState="STOP"
	else
		programState="START"
	fi
	
	ret=$(start)

	if [[ "$ret" == "1-Dodaj pravilo" ]]; then #Dodaj novo pravilo
		ret=$(oknoDodajPravilo)
		if [[ "$ret" == "1-Izberi med procesi" ]]; then #Izberi med procesi
			prog=$(oknoProcesi)
		elif [[ "$ret" == "0-" ]]; then
			prog=$(oknoIzberiDat)
		elif [[ "$ret" == "1-Vnesi ime" ]]; then
			prog=$(oknoVnesiIme)
		elif [[ "$ret" == "1-Globalno" ]]; then
			prog="G"
			echo '2' > $settingsFile #Globalno
			zenity --warning --text="Globalni nacin je vklopljen. Vsa pravila razen globalnega se ne uspostevajo." 2>/dev/null
		elif [[ "$ret" == "1-CPU Indikator" ]]; then
			oknoCPU
			cpu=$?
			if [[ "$cpu" -eq 1 ]]; then
				zenity --warning --text="CPU Ind. ON" 2>/dev/null	
			elif [[ "$cpu" -eq 0 ]]; then
				zenity --warning --text="CPU Ind. OFF" 2>/dev/null		
			fi
		fi
	elif [[ "$ret" == "1-Brisi pravila" ]]; then
		pravilo="x"
		while [ "$pravilo" != "" ]; do
			pravilo=$(oknoBrisi)
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
		dodajPravilo "$prog"
	fi

	MAIN
}

MAIN
