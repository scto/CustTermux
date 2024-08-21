# Detect the shell
SHELL_NAME=$(basename "$SHELL")

case "$SHELL_NAME" in
    "bash")
        # Bash shell detected (no action needed)
        ;;
    "zsh")
        # Zsh shell detected (no action needed)
        ;;
    "fish")
        # Fish shell detected (no action needed)
        ;;
    *)
        echo "Unsupported shell: $SHELL_NAME"
        exit 1
        ;;
esac

################################################################################################
#Utility functions
################################################################################################

wait_and_count() {
    local start_time=$(date +%s)
    local counter=0
    local spinner="/-\|"
    local bar_length=40 

    echo "[${1}] Processing..."
    while true; do
        local current_time=$(date +%s)
        local elapsed_time=$((current_time - start_time))
        if [ $elapsed_time -gt $1 ]; then
            break
        fi

        local progress=$((elapsed_time * bar_length / $1))
        printf "\r[\033[0;32m%-*s\033[0m] %d%% %c" $bar_length $(printf '#%.0s' $(seq 1 $progress)) $((elapsed_time * 100 / $1)) ${spinner:counter%4:1}
        sleep 0.1
        counter=$((counter + 1))
    done
    printf "\r[\033[0;32m%-*s\033[0m] 100%% \n" $bar_length $(printf '#%.0s' $(seq 1 $bar_length))
}


IP_ADD=""
get_ip_address() {
    local ip_address=$(termux-wifi-connectioninfo | grep -oP '(?<="ip": ")[^"]+')
    IP_ADD="$ip_address"
}


retrieve_first_line() {
    local file_path=$1
    local option=""
    if [ -f "$file_path" ]; then
        option=$(head -n 1 "$file_path")
    else
        echo "$file_path file not found or empty."
    fi
    echo "$option"
}

Init_Server_Check() {
	pkill -f "$HOME/.jiotv_go/bin/jiotv_go"
	starter=$($HOME/.jiotv_go/bin/jiotv_go bg run) #For Login Checker
}

Init_Server_Check_Regular() {
	termux-wake-lock
	#pkill -f "$HOME/.jiotv_go/bin/jiotv_go"
}

TheShowRunner() {
    pkill -f "$HOME/.jiotv_go/bin/jiotv_go"

    config_file="$HOME/.jiotv_go/bin/run.cfg"

    if [ ! -f "$config_file" ]; then
        echo "PUBLIC" > "$config_file"
		MODE_ONE="This Device Only"
		MODE_TWO="For all devices in Network [Default]"

		outputz=$(termux-dialog radio -t "Where do you want to use JioTVGo server?" -v "$MODE_TWO, $MODE_ONE")

		selected=$(echo "$outputz" | jq -r '.text')
		if [ $? != 0 ]; then
			echo "Canceled."
			exit 1
		fi

		if [ -n "$selected" ]; then
			echo "Selected: $selected"

			case "$selected" in
				"$MODE_ONE")
					echo "PRIVATE" > "$config_file"
					echo "Setting Private Server..."
					;;
				*)
					echo "Setting Public Server..."
					;;
			esac
		else
			echo "Setting Public Server..."
		fi
    fi

   

    retrieved_runner=$(head -n 1 "$config_file")

    if [ "$retrieved_runner" = "PRIVATE" ]; then
        echo "Running JioTVGo Server Locallly..."
        $HOME/.jiotv_go/bin/jiotv_go run
    else
        echo "Running JioTVGo Server..."
        $HOME/.jiotv_go/bin/jiotv_go run -P
    fi
}


LoginChecker() {
	pkill -f "$HOME/.jiotv_go/bin/jiotv_go"
}

LoginChecker_Old() {
	sleep 0.3
	URL="http://localhost:5001/live/144.m3u8"
	status_code=$(curl -X GET -o /dev/null -s -w "%{http_code}\n" "$URL")
	echo "Checking Login:[$status_code]"

	prompt_login() {
		termux-dialog confirm -t "Login Required" -i "Login Error. Proceed with login?" 
	}

	case $status_code in
		500)
			if prompt_login | grep -q "yes"; then
				send_otp
				verify_otp
			else
				echo -e "\e[31mUser chose not to login\e[0m"
			fi
			;;
		302)
			echo -e "\e[32mLogin detected!\e[0m"
			;;
		000)
			echo -e "\e[31m[$status_code]Server Error!\e[0m"
			;;
		*)
			if prompt_login | grep -q "yes"; then	
				send_otp
				verify_otp
			else
				echo -e "\e[31mUser chose not to login\e[0m"
			fi
			;;
	esac
	pkill -f "$HOME/.jiotv_go/bin/jiotv_go"
}




PHONE_NUMBER=""
send_otp() {
	source ~/.bashrc
	PHONE_NUMBER=$(termux-dialog text -t "Enter your jio number [10 digit] to login" | jq -r '.text')
	if [ $? != 0 ]; then
		echo "Canceled."
	fi

	url="http://localhost:5001/login/sendOTP"

	response=$(curl -s -X POST $url -H "Content-Type: application/json" -d "{\"number\": \"+91$PHONE_NUMBER\"}")
	echo "Please wait"
        wait_and_count 5
}

verify_otp() {

	otp=$(termux-dialog text -t "Enter your OTP" | jq -r '.text')
	if [ $? != 0 ]; then
		echo "Canceled."
	fi

	url="http://localhost:5001/login/verifyOTP"

	response=$(curl -s -X POST $url -H "Content-Type: application/json" -d "{\"number\": \"+91$PHONE_NUMBER\", \"otp\": \"$otp\"}")

	json_string=$(echo "$response" | jq -c .)

	if echo "$json_string" | grep -q "success"; then
		echo -e "\e[32mLogged in Successfully.\e[0m"
	else
		echo -e "\e[31mLogin failed.\e[0m"
	fi

}


################################################################################################
#Runner configuration functions
################################################################################################

Server_Runner() {
	get_ip_address
	$HOME/.jiotv_go/bin/jiotv_go -v
	echo "---------------------------"
	echo -e "\e[96mFor Local Access:\e[0m"
	echo -e "\e[96mLogin Page:\e[0m http://localhost:5001"
	echo -e "\e[96mIPTV Playlist:\e[0m http://localhost:5001/playlist.m3u"
	echo "---------------------------"
	echo -e "\e[93mFor External Access:\e[0m"
	echo -e "\e[93mLogin Page:\e[0m http://$IP_ADD:5001"
	echo -e "\e[93mIPTV Playlist:\e[0m http://$IP_ADD:5001/playlist.m3u"
	echo "---------------------------"

	
	source ~/.bashrc #PATH update

	retrieved_mode=$(retrieve_first_line "$HOME/.jiotv_go/bin/mode.cfg")
	retrieved_iptv=$(retrieve_first_line "$HOME/.jiotv_go/bin/iptv.cfg")

	
	if [ "$retrieved_iptv" != "NULL" ]; then
		#termux-wake-lock
		sleep 1
		Init_Server_Check_Regular
		LoginChecker
		#echo "Running JioTV GO"
		run_iptv_app = $(am start --user 0 -n "$retrieved_iptv")
		#$run_iptv_app
	fi
	
	if [ "$retrieved_mode" = "MODE_ONE" ]; then
		echo -e "MODE:\e[32mDEFAULT\e[0m"
		#termux-wake-lock
		if [ "$retrieved_iptv" = "NULL" ]; then
			#termux-wake-lock
			Init_Server_Check_Regular
			LoginChecker
			#echo "Running JioTV GO"
		fi
		TheShowRunner
		#$HOME/.jiotv_go/bin/jiotv_go run -P
	elif [ "$retrieved_mode" = "MODE_TWO" ]; then
		echo -e "MODE:\e[32mSERVERMODE\e[0m"
		#termux-wake-lock
		Init_Server_Check_Regular
		LoginChecker
		echo -e "Press \e[31mCTRL + C\e[0m to interrupt"
		TheShowRunner
		#echo -e "To Stop Server: \e[31m'$HOME/.jiotv_go/bin/jiotv_go bg kill'\e[0m"
		#$HOME/.jiotv_go/bin/jiotv_go run -P
	elif [ "$retrieved_mode" = "MODE_THREE" ]; then
		echo "MODE:STANDALONE"
		#termux-wake-lock
		Init_Server_Check
		LoginChecker
		echo -e "Press \e[31mCTRL + C\e[0m to interrupt"
		am start -a android.intent.action.VIEW -d "http://localhost:5001/" -e "android.support.customtabs.extra.SESSION" null
		#termux-open-url http://localhost:5001/
		#$HOME/.jiotv_go/bin/jiotv_go run -P
	else
		echo "____MODE____UNKNOWN____"
	fi
}


################################################################################################
#Setup config functions for installation
################################################################################################

#Checking required 
gui_req() {
	pkg install termux-am jq termux-api -y
	rm -f $HOME/.termux/termux.properties
	touch $HOME/.termux/termux.properties
	chmod 755 $HOME/.termux/termux.properties
	echo "allow-external-apps = true" >> $HOME/.termux/termux.properties
	
	#am settings get secure overlay_permission_enabled
	#MODE_ONE="Yes"
	#MODE_TWO="No"
	#output=$(termux-dialog radio -t "Give draw over other apps permission. To run server in background." -v "$MODE_ONE, $MODE_TWO")
	#selected=$(echo $output | jq -r '.text')
	#if [ "$selected" == "$MODE_ONE" ]; then
		#am start --user 0 -a android.settings.action.MANAGE_OVERLAY_PERMISSION -d "package:com.termux"
		#am start -a android.settings.action.MANAGE_OVERLAY_PERMISSION --es package com.termux
		#wait_and_count 20
	#elif [ "$selected" == "$MODE_TWO" ]; then
		#run_no
	#else
		
	#fi
	
 	
	echo "If stuck, Please clear app data and restart your device."
}

check_termux_api() {
	app_permission_check (){
		mkdir -p "$HOME/.jiotv_go/bin/"
		touch "$HOME/.jiotv_go/bin/permission.cfg"
		#chmod 755 "$HOME/.jiotv_go/bin/permission.cfg"
		quick_var=$(head -n 1 "$HOME/.jiotv_go/bin/permission.cfg")	
		if [ "$quick_var" = "OVERLAY=TRUE" ]; then
			""
		else
			am start --user 0 -a android.settings.MANAGE_UNKNOWN_APP_SOURCES -d "package:com.termux"
			echo "waiting for app install permissions"
			wait_and_count 20
			echo "OVERLAY=TRUE" > "$HOME/.jiotv_go/bin/permission.cfg"
		fi
	}

	check_package() {
		#app_permission_check
		# Function to check if the package is available
		PACKAGE_NAME="com.termux.api"
		out="$(pm path $PACKAGE_NAME --user 0 2>&1 </dev/null)"
		
		# Check if the output contains the package path
		if [[ "$out" == *"$PACKAGE_NAME"* ]]; then
			echo -e "The package \e[32m$PACKAGE_NAME\e[0m is available."
			am start --user 0 -n com.termux/com.termux.app.TermuxActivity
			echo "If stuck, Please clear app data and restart your device."
			return 0
		else
			return 1
		fi

	}

    while ! check_package; do
        echo "The package $PACKAGE_NAME is not installed. Checking again..."
		curl -L -o "$HOME/Tapi.apk" "https://github.com/termux/termux-api/releases/download/v0.50.1/termux-api_v0.50.1+github-debug.apk"
		chmod 755 "$HOME/Tapi.apk"
		termux-open "$HOME/Tapi.apk"
        wait_and_count 20
    done

}



select_autoboot_or_not() {
    MODE_ONE="NO"
    MODE_TWO="YES - This will install TERMUX:BOOT [Experimental]"

	touch $HOME/.jiotv_go/bin/autoboot_or_not.cfg 
    
    outputw=$(termux-dialog radio -t "Do you want to autostart Server at boot?" -v "$MODE_ONE, $MODE_TWO")

    selected=$(echo "$outputw" | jq -r '.text')
    if [ $? != 0 ]; then
        echo "Canceled."
        exit 1
    fi

    if [ -n "$selected" ]; then
        echo "Selected: $selected"

        case "$selected" in
            "$MODE_ONE")
                echo "NO" > "$HOME/.jiotv_go/bin/autoboot_or_not.cfg"
                ;;
            "$MODE_TWO")
                echo "YES" > "$HOME/.jiotv_go/bin/autoboot_or_not.cfg"
                ;;
            *)
                echo "Unknown mode selected: $selected"
                exit 1
                ;;
        esac
    else
        echo "No mode selected, setting default mode (MODE_ONE)."
        echo "NO" > "$HOME/.jiotv_go/bin/autoboot_or_not.cfg"
    fi
}

autoboot() {
	app_permission_check (){
		mkdir -p "$HOME/.jiotv_go/bin/"
		touch "$HOME/.jiotv_go/bin/permission.cfg"
		#chmod 755 "$HOME/.jiotv_go/bin/permission.cfg"
		quick_var=$(head -n 1 "$HOME/.jiotv_go/bin/permission.cfg")	
		if [ "$quick_var" = "OVERLAY=TRUE" ]; then
			""
		else
			am start --user 0 -a android.settings.MANAGE_UNKNOWN_APP_SOURCES -d "package:com.termux"
			echo "Waiting for app install permissions"
			wait_and_count 15
			echo "OVERLAY=TRUE" > "$HOME/.jiotv_go/bin/permission.cfg"
		fi

	}

    # Function to check if com.termux.boot package is available
	check_package() {
		#app_permission_check
		# Function to check if the package is available
		PACKAGE_NAME="com.termux.boot"
		out="$(pm path $PACKAGE_NAME --user 0 2>&1 </dev/null)"
		
		# Check if the output contains the package path
		if [[ "$out" == *"$PACKAGE_NAME"* ]]; then
			echo -e "The package \e[32m$PACKAGE_NAME\e[0m is available."
			set_active=$(am start --user 0 -n com.termux/com.termux.app.TermuxActivity)
			return 0
		else
			return 1
		fi
	}

	# Loop until the package is available
    while ! check_package; do
        echo "The package $PACKAGE_NAME is not installed. Checking again..."
		curl -L -o "$HOME/Tboot.apk" "https://github.com/termux/termux-boot/releases/download/v0.8.1/termux-boot-app_v0.8.1+github.debug.apk"
		chmod 755 "$HOME/Tboot.apk"
		termux-open "$HOME/Tboot.apk"
        wait_and_count 20
    done

	boot_file() {
		mkdir -p "$HOME/.termux/boot/"
		rm -f "$HOME/.termux/boot/start_jio.sh"
		touch "$HOME/.termux/boot/start_jio.sh"

		echo "Creating Boot files: Please wait..."

		echo "#!/data/data/com.termux/files/usr/bin/sh" > ~/.termux/boot/start_jio.sh
		echo "termux-wake-lock" >> ~/.termux/boot/start_jio.sh
		echo "termux-toast -g bottom 'Starting JioTV Go Server'" >> ~/.termux/boot/start_jio.sh
		echo "/data/data/com.termux/files/home/.jiotv_go/bin/jiotv_go run -public" >> ~/.termux/boot/start_jio.sh
		echo "$HOME/.jiotv_go/bin/jiotv_go bg run -P" >> ~/.termux/boot/start_jio.sh
		
		chmod 777 "$HOME/.termux/boot/start_jio.sh"
		wait_and_count 10
	}
	
	boot_file

	Install_Alert=$(termux-dialog spinner -v "Termux:Boot Installed Successfully" -t "CustTermux")
	
	am start --user 0 -n com.termux.boot/com.termux.boot.BootActivity
	sleep 3
	am start --user 0 -n com.termux/com.termux.app.TermuxActivity
		
}


#Default Installation - Taken from rabilrbl autoinstall script.
Default_Installation() {
	OS=""
	case "$OSTYPE" in
		"linux-android"*)
			OS="android"
			;;
		"linux-"*)
			OS="linux"
			;;
		"darwin"*)
			OS="darwin"
			;;
		*)
			echo "Unsupported operating system: $OSTYPE"
			exit 1
			;;
	esac



	echo "Step 1: Identified operating system as $OS"
	ARCH=$(uname -m)

	case $ARCH in
		"x86_64")
			ARCH="amd64"
			;;
		"aarch64" | "arm64")
			ARCH="arm64"
			;;
		"i386" | "i686")
			ARCH="386"
			;;
		"arm"*)
			ARCH="arm"
			;;
		*)
			echo "Unsupported architecture: $ARCH"
			exit 1
			;;
	esac

	echo "Step 2: Identified processor architecture as $ARCH"

	# Create necessary directories
	if [[ ! -d "$HOME/.jiotv_go" ]]; then
		mkdir -p "$HOME/.jiotv_go"
	fi
	if [[ ! -d "$HOME/.jiotv_go/bin" ]]; then
		mkdir -p "$HOME/.jiotv_go/bin"
	fi
	echo "Step 3: Created \$HOME/.jiotv_go/bin"

	if [ "$OS" = "android" ] && [ "$ARCH" = "386" ]; then
		OS="linux"
	fi

        if [ "$OS" = "android" ] && [ "$ARCH" = "arm" ]; then
		OS="linux"
	fi

	# Set binary URL
	BINARY_URL="https://github.com/rabilrbl/jiotv_go/releases/latest/download/jiotv_go-$OS-$ARCH"

	# Download the binary
	curl -SL --progress-bar --retry 2 --retry-delay 2 -o "$HOME/.jiotv_go/bin/jiotv_go" "$BINARY_URL" || { echo "Failed to download binary"; exit 1; }

	echo "Step 4: Fetch the latest binary"

	# Make the binary executable
	chmod +x "$HOME/.jiotv_go/bin/jiotv_go"
	echo "Step 5: Granted executable permissions to the binary"

	# Add binary to PATH
	case "$SHELL_NAME" in
		"bash")
			export PATH="$PATH:$HOME/.jiotv_go/bin"
			echo "export PATH=$PATH:$HOME/.jiotv_go/bin" >> "$HOME/.bashrc"
			;;
		"zsh")
			export PATH=$PATH:$HOME/.jiotv_go/bin
			echo "export PATH=$PATH:$HOME/.jiotv_go/bin" >> "$HOME/.zshrc"
			;;
		"fish")
			echo "set -gx PATH $PATH $HOME/.jiotv_go/bin" >> "$HOME/.config/fish/config.fish"
			echo "Please restart your terminal or run source $HOME/.config/fish/config.fish"
			;;
		*)
			echo "Unsupported shell: $SHELL_NAME"
			exit 1
			;;
	esac
}


################################################################################################
#GUI Functions
################################################################################################


select_mode() {
    # Create necessary directories
    if [[ ! -d "$HOME/.jiotv_go" ]]; then
        mkdir -p "$HOME/.jiotv_go"
    fi
    if [[ ! -d "$HOME/.jiotv_go/bin" ]]; then
        mkdir -p "$HOME/.jiotv_go/bin"
    fi
    
	MODE_ONE="Default Mode: Launch CustTermux to run server & auto-redirect to IPTV player [for TV]."
	MODE_TWO="Server Mode: Run server on your phone and watch on your TV [for Phone]."
	MODE_THREE="Standalone App Mode: Access JioTV Go via webpage [for Phone]."

    
    outputf=$(termux-dialog radio -t "Select Usage Method for CustTermux" -v "$MODE_ONE, $MODE_TWO") #$MODE_THREE

    selected=$(echo "$outputf" | jq -r '.text')
    if [ $? != 0 ]; then
        echo "Canceled."
        exit 1
    fi

    if [ -n "$selected" ]; then
        echo "Selected: $selected"

        case "$selected" in
            "$MODE_ONE")
                echo "MODE_ONE" > "$HOME/.jiotv_go/bin/mode.cfg"
                ;;
            "$MODE_TWO")
                echo "MODE_TWO" > "$HOME/.jiotv_go/bin/mode.cfg"
                ;;
			"$MODE_THREE")
                echo "MODE_THREE" > "$HOME/.jiotv_go/bin/mode.cfg"
                ;;
            *)
                echo "Unknown mode selected: $selected"
                exit 1
                ;;
        esac
    else
        echo "No mode selected, setting default mode (MODE_ONE)."
        echo "MODE_ONE" > "$HOME/.jiotv_go/bin/mode.cfg"
    fi
}

select_iptv() {
	spr="SparkleTV2 - any app"	
	outputx=$(termux-dialog radio -t "Select an IPTV Player to autostart" -v "OTTNavigator,Televizo,SparkleTV,TiviMate,Kodi,$spr,none")

	selected=$(echo "$outputx" | jq -r '.text')
	if [ $? != 0 ]; then
 		rm -rf "$HOME/.jiotv_go/bin/iptv.cfg"
		echo "NULL" > "$HOME/.jiotv_go/bin/iptv.cfg"
	fi
	

	if [ -n "$selected" ]; then
		echo "Selected: $selected"

		case "$selected" in
			OTTNavigator)
   				rm -rf "$HOME/.jiotv_go/bin/iptv.cfg"
				echo "studio.scillarium.ottnavigator/studio.scillarium.ottnavigator.MainActivity" > "$HOME/.jiotv_go/bin/iptv.cfg"
				;;
			Televizo)
   				rm -rf "$HOME/.jiotv_go/bin/iptv.cfg"
				echo "com.ottplay.ottplay/com.ottplay.ottplay.StartActivity" > "$HOME/.jiotv_go/bin/iptv.cfg"
				;;
			SparkleTV)
   				rm -rf "$HOME/.jiotv_go/bin/iptv.cfg"
				echo "se.hedekonsult.sparkle/se.hedekonsult.sparkle.MainActivity" > "$HOME/.jiotv_go/bin/iptv.cfg"
				;;
			TiviMate)
   				rm -rf "$HOME/.jiotv_go/bin/iptv.cfg"
				echo "ar.tvplayer.tv/ar.tvplayer.tv.ui.MainActivity" > "$HOME/.jiotv_go/bin/iptv.cfg"
				;;
			Kodi)
   				rm -rf "$HOME/.jiotv_go/bin/iptv.cfg"
				echo "org.xbmc.kodi/org.xbmc.kodi.Splash" > "$HOME/.jiotv_go/bin/iptv.cfg"
				;;
			$spr)
   				rm -rf "$HOME/.jiotv_go/bin/iptv.cfg"
				echo "com.skylake.siddharthsky.sparkletv2/com.skylake.siddharthsky.sparkletv2.MainActivity" > "$HOME/.jiotv_go/bin/iptv.cfg"
				;;
			none)
   				rm -rf "$HOME/.jiotv_go/bin/iptv.cfg"
				echo "NULL" > "$HOME/.jiotv_go/bin/iptv.cfg"
				;;
		esac
	else
 		rm -rf "$HOME/.jiotv_go/bin/iptv.cfg"
		echo "NULL" > "$HOME/.jiotv_go/bin/iptv.cfg"
	fi
}



FINAL_INSTALL() {

	retrieved_mode=$(retrieve_first_line "$HOME/.jiotv_go/bin/mode.cfg")

	case "$retrieved_mode" in
		"MODE_ONE")
			echo "Setting Default Mode"

			select_autoboot_or_not
			
			retrieved_boot_or_not=$(head -n 1 "$HOME/.jiotv_go/bin/autoboot_or_not.cfg")

			case "$retrieved_boot_or_not" in
                "NO")
			;;
			    "YES")
				echo "Setting AutoBoot"
				autoboot
            ;;
                *)
			esac

			select_iptv
			Init_Server_Check
			send_otp
			verify_otp
			pkill -f "$HOME/.jiotv_go/bin/jiotv_go"
			#$HOME/.jiotv_go/bin/jiotv_go bg kill
            $HOME/.jiotv_go/bin/jiotv_go epg gen
			echo "Running : \$HOME/.jiotv_go/bin/jiotv_go run -P"
			;;
		"MODE_TWO")
			echo "Setting Server Mode"
			#autoboot
			echo "NULL" > "$HOME/.jiotv_go/bin/iptv.cfg"
			Init_Server_Check	
			send_otp
			verify_otp
			pkill -f "$HOME/.jiotv_go/bin/jiotv_go"
            $HOME/.jiotv_go/bin/jiotv_go epg gen
			#$HOME/.jiotv_go/bin/jiotv_go bg kill
			echo "Running : \$HOME/.jiotv_go/bin/jiotv_go run -P"
			;;
		"MODE_THREE")
			echo "Setting Standalone Mode"
			echo "NULL" > "$HOME/.jiotv_go/bin/iptv.cfg"
			Init_Server_Check
			send_otp
			verify_otp
			pkill -f "$HOME/.jiotv_go/bin/jiotv_go"
			#$HOME/.jiotv_go/bin/jiotv_go bg kill
			echo "jiotv_go has been downloaded and added to PATH."
			;;
		*)
			echo "mode.cfg file not found or empty."
			;;
	esac
}


######################################################################################
######################################################################################
######################################################################################
######################################################################################
######################################################################################
######################################################################################


# Check if jiotv_go exists
if [[ -f "$HOME/.jiotv_go/bin/jiotv_go" ]]; then
	Server_Runner
fi

#sleep 2
echo "Script :version 6.4"

FILE_PATH="$HOME/.jiotv_go/bin/run_check.cfg"

if [ ! -f "$FILE_PATH" ]; then
	mkdir -p "$HOME/.jiotv_go/bin/"
    echo "FIRST_RUN" > "$FILE_PATH"
	echo "-----------------------"
	echo "INSTALLATION -- PART 1"
	echo "-----------------------"
	gui_req
	echo "SECOND_RUN" > "$FILE_PATH"
	am startservice -n com.termux/.app.TermuxService -a com.termux.service_execute
else
    RUN_STATUS=$(cat "$FILE_PATH")

    if [ "$RUN_STATUS" == "FIRST_RUN" ]; then
       	echo "-----------------------"
        echo "INSTALLATION -- PART 1"
		echo "-----------------------"
		gui_req
		echo "SECOND_RUN" > "$FILE_PATH"
		am startservice -n com.termux/.app.TermuxService -a com.termux.service_execute
	elif [ "$RUN_STATUS" == "SECOND_RUN" ]; then
       	echo "-----------------------"
        echo "INSTALLATION -- PART 2"
		echo "-----------------------"
		check_termux_api
		select_mode
		Default_Installation
		FINAL_INSTALL
		echo "FINAL_RUN" > "$FILE_PATH"
		Server_Runner
		echo -e "----------------------------"
		echo -e "\e[0;36mCustTermux by SiddharthSky\e[0m"
		echo -e "----------------------------"
	elif [ "$RUN_STATUS" == "FINAL_RUN" ]; then
		echo ""
    else 
       echo "Something Went Wrong : Clear App Data"
	   sleep 30
	   exit 1
    fi
fi

################################################################################################
#END
################################################################################################


