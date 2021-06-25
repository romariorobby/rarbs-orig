#!/bin/sh

while getopts ":a:r:b:p:s:h" o; do case "${o}" in
	h) printf "Optional arguments for custom use:\\n  -r: Dotfiles repository (local file or url)\\n  -p: Dependencies and programs csv (local file or url)\\n  -s: Homebrew Source(tap)\\n  -a: AUR helper (must have pacman-like syntax)\\n  -h: Show this message\\n" && exit 1 ;;
	r) dotfilesrepo=${OPTARG} && chezmoi git ls-remote "$dotfilesrepo" || exit 1 ;;
	b) repobranch=${OPTARG} ;;
	p) progsfile=${OPTARG} ;;
	s) brewtapfile=${OPTARG} ;;
	a) aurhelper=${OPTARG} ;;
	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit 1 ;;
esac done

[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/romariorobby/dotfiles.git"
[ -z "$sshdotfilesrepo" ] && sshdotfilesrepo="git@github.com:romariorobby/dotfiles.git"
[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/romariorobby/rarbs/master/progs.csv"
[ -z "$brewtapfile" ] && brewtapfile="https://raw.githubusercontent.com/romariorobby/rarbs/master/opt/brewtap.csv"
[ -z "$aurhelper" ] && aurhelper="paru-bin"

installpkg() { \
	if [[ -f "/etc/arch-release" ||  -f "/etc/artix-release" ]]; then
		pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
	elif [ "$(uname)" == "Darwin" ]; then
		brew install "$1" >/dev/null 2>&1
	fi
}

tapbrew(){ \
	brew tap "$1" >/dev/null 2>&1
}

error() { clear; printf "ERROR:\\n%s\\n" "$1" >&2; exit 1;}

welcomemsg() { \
	dialog --title "Welcome!" --msgbox "Buggy Bootstrap\\n\\nThis script will automatically install a fully-featured $(echo $OS) desktop.\\n\\n-Romario" 10 60
	dialog --colors --title "Important Note!" --yes-label "All ready!" --no-label "Return..." --yesno "If you running GNU/LINUX(Arch), Be sure the computer you are using has current pacman updates and refreshed Arch keyrings.\\n\\nIf it does not, the installation of some programs might fail." 8 70
	}

rarbtype() { \
	dialog --no-cancel --backtitle "RARBS Type Installation" --radiolist "Select RARBS Type: " 10 60 3 \
		M "Minimal" on \
		F "Full" off 2> rarbstype
		RARBSTYPE="$(cat rarbstype)"
}

getuserandpass() { \
	# Prompts user for new username an password.
	name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(dialog --no-cancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done ;}

usercheck() { \
	! { id -u "$name" >/dev/null 2>&1; } ||
	dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "No wait..." --yesno "The user \`$name\` already exists on this system. RARBS can install for a user already existing, but it will \\Zboverwrite\\Zn any conflicting settings/dotfiles on the user account.\\n\\nRARBS will \\Zbnot\\Zn overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that RARBS will change $name's password to the one you just gave." 14 70
	}

isuserbw() { \
	dialog --title "Install Bitwarden" --yesno "Do you want login bitwarden?" 8 90 && getbwuserandpass && addbwuserandpass || clear
}

getbwuserandpass() { \
	bwname=$(dialog --inputbox "First, please enter a email address for bitwarden ." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$bwname" | grep -q '\S\+@\S\+\.[A-Za-z]\+'; do
		bwname=$(dialog --no-cancel --inputbox "Email Address not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	bwpass1=$(dialog --no-cancel --inputbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	bwpass2=$(dialog --no-cancel --inputbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$bwpass1" = "$bwpass2" ]; do
		unset bwpass2
		bwpass1=$(dialog --no-cancel --inputbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		bwpass2=$(dialog --no-cancel --inputbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done ;}

addbwuserandpass () {
	dialog --infobox "Adding Bitwarden-cli user \"$bwname\" for $name..." 4 50
	[ -x "$(command -v "bw")" ] || manualinstall bitwarden-cli-bin >/dev/null 2>&1
	bwdir="/home/$name/.local/share/bitwarden"; mkdir -p "$bwdir"; chown -R "$name":wheel "$(dirname "$bwdir")"
	[ -f "$bwdir/email" -a -f "$bwdir/key"  ] && cp $bwdir/email $bwdir/email.bak && cp $bwdir/key $bwdir/email.bak
	sudo -u "$name" echo $bwname > $bwdir/email && sudo -u "$name" echo $bwpass1 > $bwdir/key
	touch $bwdir/clientid && touch $bwdir/clientsecret
	sudo -u "$name" bw login $(echo $bwname $bwpass1)
	dialog --infobox "Adding Environment Variables Locally..." 4 50
	export BW_MASTER=$(echo "$bwdir/key") || error "FAILED ADDING BW_MASTER"
	export BW_SESSION="$(bw unlock $BW_MASTER 2>/dev/null | grep 'export' | sed -E 's/.*export BW_SESSION="(.*==)"$/\1/')" || error "FAILED BW_SESSION"
	}

preinstallmsg() { \
	dialog --title "Let's get this party started!" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || { clear; exit 1; }
	}

adduserandpass() { \
	# Adds user `$name` with password $pass1.
	dialog --infobox "Adding user \"$name\"..." 4 50
	useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
	usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	repodir="/home/$name/.local/src"; mkdir -p "$repodir"; chown -R "$name":wheel "$(dirname "$repodir")"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2 ;}

refreshkeys() { \
	dialog --infobox "Refreshing Arch Keyring..." 4 40
	pacman -Q artix-keyring >/dev/null 2>&1 && pacman --noconfirm -S artix-keyring >/dev/null 2>&1
	pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
	}

newperms() { # Set special sudoers settings for install (or after).
	sed -i "/#RARBS/d" /etc/sudoers
	echo "$* #RARBS" >> /etc/sudoers ;}

maininstall() { # Installs all needed programs from main repo.
	dialog --title "RARBS Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 5 70
	installpkg "$1"
	}

maintap() {
	dialog --title "RARBS Homebrew Source" --infobox "Adding \`$1\` to Homebrew ($s of $totaltap). $1 $2" 5 70
	tapbrew "$1"
}
chezgitrepo() { # Clone and install dotfiles using chezmoi
	dialog --infobox "Downloading and installing config files..." 4 60
	[ -x "$(command -v "chezmoi")" ] || installpkg chezmoi >/dev/null 2>&1
	sudo -u "$name" chezmoi init --apply "$1"
	}

gitmakeinstall() {
	progname="$(basename "$1" .git)"
	dir="$repodir/$progname"
	dialog --title "RARBS Installation" --infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 5 70
	sudo -u "$name" git clone --depth 1 "$1" "$dir" >/dev/null 2>&1 || { cd "$dir" || return 1 ; sudo -u "$name" git pull --force origin master;}
	cd "$dir" || exit 1
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return 1 ;}
gitmakeinstalltemp() {
	# progname="$(basename "$1" .git)"
	dest="$repodir"
	# dest="$repodir/$progname"
	git clone "$1" "$dest" >/dev/null 2>&1
	cd "$dest/dwm" && make >/dev/null 2>&1 && make install >/dev/null 2>&1 || exit 1
	cd "$dest/st" && make >/dev/null 2>&1 && make install >/dev/null 2>&1 || exit 1
	cd "$dest/yadav-dwmblocks" && make >/dev/null 2>&1 && make install >/dev/null 2>&1 || exit 1
	cd "$dest/dmenu" && make >/dev/null 2>&1 && make install >/dev/null 2>&1 || exit 1
	cd /tmp || return 1 ;}
manualinstall(){
	[ -f "/usr/bin/$1" ] || (
	dialog --infobox "Installing \"$1\", an AUR helper..." 4 50
	cd /tmp || exit 1
	rm -rf /tmp/"$1"*
	sudo -u "$name" git clone https://aur.archlinux.org/$1.git &&
	cd $1 && sudo -u "$name" makepkg -si --noconfirm >/dev/null 2>&1
	cd /tmp || return 1) ;}

insbrew(){ \
	echo "Installing XCode CLT..."
	[ -d "/Library/Developer/CommandLineTools" ] && echo "Xcode Installed.." || xcode-select --install
	[ -x "$(command -v "brew")" ] && echo "Brew Already Installed" || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
	brew update
}

aurinstall() { \
	dialog --title "RARBS Installation" --infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" 5 70
	echo "$aurinstalled" | grep -q "^$1$" && return 1
	sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
	}

pipinstall() { \
	dialog --title "RARBS Installation" --infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 5 70
	if [ "$(uname)" == "Darwin" ]; then
		[ -x "$(command -v "pip")" ] || curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python3 get-pip.py >/dev/null 2>&1
	else 
		[ -x "$(command -v "pip")" ] || installpkg python-pip >/dev/null 2>&1
	fi
	yes | pip install "$1"
	}

npminstall() { \
	dialog --title "RARBS Installation" --infobox "Installing the NPM package \`$1\` ($n of $total). $1 $2" 5 70
	[ -x "$(command -v "npm")" ] || installpkg npm >/dev/null 2>&1
	npm install -g "$1"
	}

# TODO: Refactor Ugly code
installationloop() { \
	if [ "$(uname)" == "Darwin" ]; then
		if [ $RARBSTYPE == "M" ]; then
			([ -f "$progsfile" ] && grep "^[HPN]," $progsfile > /tmp/progs.csv ) || curl -Ls "$progsfile" | grep "^[HPN]," > /tmp/progs.csv
			([ -f "$brewtapfile" ] && grep "^M," $brewtapfile > /tmp/brewtap.csv ) || curl -Ls "$brewtapfile" | grep "^M," > /tmp/brewtap.csv
		else
			([ -f "$progsfile" ] && sed '/^[#AM]/d' $progsfile > /tmp/progs.csv ) || curl -Ls "$progsfile" | sed '/^[#AM]/d' > /tmp/progs.csv
			([ -f "$brewtapfile" ] && sed '/^#/d' $brewtapfile > /tmp/brewtap.csv ) || curl -Ls "$brewtapfile" | sed '/^#/d' > /tmp/brewtap.csv
		fi
	else
		if [ $RARBSTYPE == "M" ]; then
			([ -f "$progsfile" ] && grep "^[AMPN]," "$progsfile" > /tmp/progs.csv) || curl -Ls "$progsfile" | grep "^[AMPN]," > /tmp/progs.csv
		else
			([ -f "$progsfile" ] && sed '/^[#H]/d' "$progsfile" > /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^[#H]/d' > /tmp/progs.csv
		fi
	fi
	totaltap=$(wc -l < /tmp/brewtap.csv)
	while IFS=, read -r tag source comment; do
		s=$((s+1))
		echo "$comment" | grep -q "^\".*\"$" && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"M") maintap "$source" "$comment" ;;
		esac
	done < /tmp/brewtap.csv
	# TODO: Make Read from org file del/IFS="|"
	# ([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -lLs "$progsfile" | sed '/^-\|*\|#/d;/^|-/d' > /tmp/progs.csv
	total=$(wc -l < /tmp/progs.csv)
	aurinstalled=$(pacman -Qqm)
	while IFS=, read -r tag program comment; do
		n=$((n+1))
		echo "$comment" | grep -q "^\".*\"$" && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		# Arch-Linux
		if [[ -f "/etc/arch-release" || -f "/etc/artix-release" ]]; then
			if [ "$RARBSTYPE" == "M" ]; then
				case "$tag" in
					"M") maininstall "$program" "$comment" ;;
					"A") aurinstall "$program" "$comment" ;;
				esac
			else
				case "$tag" in
					"M"|"MO") maininstall "$program" "$comment" ;;
					"A"|"AO") aurinstall "$program" "$comment" ;;
				esac
			fi
		# MacOS
		else
			if [ "$RARBSTYPE" == "M" ]; then
				case "$tag" in
					"H") maininstall "$program" "$comment" ;;
				esac
			else
				case "$tag" in
					"H"|"HO") maininstall "$program" "$comment" ;;
					# "HO") maininstall "$program" "$comment" ;;
				esac
			fi
		fi
		if [ "$RARBSTYPE" == "M" ]; then
			case "$tag" in
				"P") pipinstall "$program" "$comment" ;;
				"N") npminstall "$program" "$comment" ;;
				# "C") chezmoiinstall "$program" "$comment" ;;
				# "G") gitmakeinstalltemp "$program" "$comment" ;;
			esac
		else
			case "$tag" in
				"P"|"PO") pipinstall "$program" "$comment" ;;
				"N"|"NO") npminstall "$program" "$comment" ;;
				# "C"|"CO") chezmoiinstall "$program" "$comment" ;;
				# "G"|"GO") gitmakeinstalltemp "$program" "$comment" ;;
			esac
		fi
	done < /tmp/progs.csv ;}

systembeepoff() {
	dialog --infobox "Getting rid of that retarded error beep sound..." 10 50
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;}

symlink(){ \
	[ -f "/etc/bash.bashrc" ] && echo '
	if [ -s "${XDG_CONFIG_HOME:-$HOME/.config}/bash/.bashrc" ]; then
			. "${XDG_CONFIG_HOME:-$HOME/.config}/bash/.bashrc"
	fi
	' >> /etc/bash.bashrc
	if [ "$(uname)" == "Darwin" ]; then
		# Init
		cd $HOME && rm .bashrc .bash_history .bash_profile .bash_logout .zsh_history
		[ -d $HOME/.local/share/chezmoi ] && chezmoi -v apply

		# Symlink profile shell if exist
		[ -d $HOME/.config/shell ] && ln -sf $HOME/.config/shell/profile $HOME/.profile &&
		ln -sf $HOME/.config/shell/profile $HOME/.zprofile && echo "Symlink Shell"
	else
		# Init
		cd /home/$name && rm .bashrc .bash_history .bash_profile .bash_logout
		[ -d /home/$name/.local/share/chezmoi ] && sudo -u "$name" chezmoi -v apply

		# Symlink profile shell if exist
		[ -d /home/$name/.config/shell ] && ln -sf /home/$name/.config/shell/profile /home/$name/.profile &&
		ln -sf /home/$name/.config/shell/profile /home/$name/.zprofile && echo "Symlink Shell"

		# Symlink profile x11 if exist
		[ -d /home/$name/.config/x11 ] && ln -sf /home/$name/.config/x11/xinitrc /home/$name/.xinitrc &&
		ln -sf /home/$name/.config/x11/xprofile /home/$name/.xprofile && echo "Symlink X11"
	fi
}

# TODO: Complete Cleanup
cleanup() { \
	dialog --title "Cleanup" --yesno "Do you want clean all caches?" 8 90
	mv rarbstype ~/.local/share
	

}

finalize(){ \
	dialog --infobox "Preparing welcome message..." 4 50
	if [ "$(uname)" == "Darwin" ]; then
		dialog --title "All done, MAC!" --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\n Some configurations needed to restart .\\n\\n.t Romario" 12 80
	else
		dialog --title "All done, LINUX!" --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"startx\" to start the graphical environment (it will start automatically in tty1).\\n\\n.t Romario" 12 80
	fi
	}

