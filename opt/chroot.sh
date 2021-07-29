#Potential variables: timezone, lang and local
rarbsUrl="https://raw.githubusercontent.com/romariorobby/rarbs/master/rarbs"
gitrarbsUrl="https://github.com/romariorobby/rarbs"
echo "======================"
echo "========CHROOT========"
echo "======================"
echo "-----ROOT PASSWORD----"
echo "----------------------"
passwd

grep -q "^Color" /etc/pacman.conf || sed -i "s/^#Color$/Color/" /etc/pacman.conf
grep -q "^ParallelDownloads" /etc/pacman.conf || sed -i "s/#Parallel/Parallel/" /etc/pacman.conf
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
pacman -Syy
driveUser=$(cat drivepath.tmp)
TZuser=$(cat tzfinal.tmp)
ln -sf /usr/share/zoneinfo/$TZuser /etc/localtime

hwclock --systohc

echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "en_US ISO-8859-1" >> /etc/locale.gen
hname="/etc/hostname"
printf "127.0.0.1\tlocalhost
::1\t\tlocalhost
127.0.0.1\t$(cat $hname).localdomain\t$(cat $hname)\n" >> /etc/hosts

locale-gen
NETMD=""
if [ $(cat archtype.tmp) = "X" ]; then
    pidof runit && echo "Daemon Using Runit" && NETMD="networkmanager-runit"
    pidof init && echo "Daemon Using openrc" && NETMD="networkmanager-openrc"
    pidof s6 && echo "Daemon Using s6" && NETMD="networkmanager-s6"
fi

pacman --noconfirm --needed -S networkmanager $NETMD dialog openssh git

if [ $(cat archtype.tmp) = "A" ];then
    systemctl enable NetworkManager
    systemctl enable sshd
    systemctl start NetworkManager
# TODO: make works for all DAEMON TYPE
#else
#    ln -s /etc/runit/sv/NetworkManager /run/runit/service
#    ln -s /etc/runit/sv/sshd /run/runit/service
fi

if [ $(cat installtype.tmp) = "U" ];then
    sed -i "s/^HOOKS/#HOOKS/g" && echo "HOOKS=(base udev autodetect mdconf block filesytems keyboard fsck)" >> /etc/mkinitcpio.conf
    mkinitcpio -p linux
    [ ! -f /etc/systemd/journald.conf.d/usbstick.conf ] && mkdir -p /etc/systemd/journald.conf.d && printf '[Journal]
    Storage=volatile
    RuntimeMaxUse=30M' > /etc/systemd/journald.conf.d/usbstick.conf
fi

uefigrub(){
    pacman --noconfirm --needed -S grub efibootmgr mtools dosfstools && grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB && grub-mkconfig -o /boot/grub/grub.cfg
}
usbuefigrub(){
    pacman --noconfirm --needed -S grub efibootmgr mtools dosfstools && grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable --recheck && grub-mkconfig -o /boot/grub/grub.cfg
}
    
legacygrub(){
    pacman --noconfirm --needed -S grub && grub-install --target=i386-pc $driveUser && grub-mkconfig -o /boot/grub/grub.cfg
}

echo "=========================================="
echo "Installing GRUB"
echo "=========================================="
if [ $(cat installtype.tmp) = "U" ]; then
    usbuefigrub
else
    ls /sys/firmware/efi/efivars >/dev/null 2>&1 && uefigrub || legacygrub
fi

if [ $(cat archtype.tmp) = "X" ]; then
    echo "=========================================="
    echo "Installing Archlinux Repositories to Artix"
    echo "=========================================="
    pacman --noconfirm -S artix-archlinux-support
    printf '\n#Arch Repositories
[extra]
Include = /etc/pacman.d/mirrorlist-arch\n
[community]
Include = /etc/pacman.d/mirrorlist-arch\n
[multilib]
Include = /etc/pacman.d/mirrorlist-arch\n' >> /etc/pacman.conf && echo "Adding Arch Repositories...."
    pacman-key --init
    pacman-key --populate artix
    pacman -Syy
    pidof runit >/dev/null 2>&1 && dialog --title "Important Note!"  --msgbox "Don't Forget to run this:\n Internet Access\n \n  ln -s /etc/runit/sv/NetworkManager /run/runit/service" 10 70
fi

gitrarbs() { git clone $gitrarbsUrl && cd rarbs && bash rarbs;}
rarbs() { curl $rarbsUrl > rarbs.sh && bash rarbs.sh ;}
dialog --title "Install RARBS" --yesno "This install script will easily let you access Romario's Auto-Rice Boostrapping Scripts (RARBS) which automatically install a full Arch Linux .\n\nIf you'd like to install this, select yes, otherwise select no.\n\nRomario"  15 60 && gitrarbs

