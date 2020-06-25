apt-get install mkisofs xorriso gzip cpio rsync

ISO_URL="http://archive.ubuntu.com/ubuntu/dists/focal/main/installer-amd64/current/legacy-images/netboot/mini.iso"

BASE_DIR="`mktemp -d -p /tmp ubuntu-XXXXXX`"

UBUNTU_ISO="$BASE_DIR/ubuntu.iso" && touch "$UBUNTU_ISO"
UBUNTU_MBR="$BASE_DIR/ubuntu.mbr" && touch "$UBUNTU_MBR"
UBUNTU_ISO_DIR="$BASE_DIR/ubuntu" && mkdir -p "$UBUNTU_ISO_DIR"
BUILD_DIR="$BASE_DIR/build" && mkdir -p "$BUILD_DIR"
TEMP_DIR="$BASE_DIR/temp" && mkdir -p "$TEMP_DIR"
CUSTOM_ISO_DIR="$BASE_DIR/custom" && mkdir -p "$CUSTOM_ISO_DIR"
CUSTOM_ISO="$BASE_DIR/custom.iso" && touch "$CUSTOM_ISO"

TXT_CFG="$BUILD_DIR/txt.cfg"
GRUB_CFG="$BUILD_DIR/boot/grub/grub.cfg"

TXT_LINE="append vga=788 initrd=initrd.gz \-\-\- quiet"
GRUB_LINE="linux\t\/linux \-\-\- quiet"

PRESEED="\/preseed.cfg"
APPEND_LINE="auto=true priority=critical file=$PRESEED"

wget "$ISO_URL" -O "$UBUNTU_ISO"
mount -o loop "$UBUNTU_ISO" "$UBUNTU_ISO_DIR"
rsync -av "$UBUNTU_ISO_DIR/" "$BUILD_DIR"
umount "$UBUNTU_ISO_DIR"
dd if="$UBUNTU_ISO" bs=1 count=446 of="$UBUNTU_MBR"

sed -i "s/$GRUB_LINE/$GRUB_LINE $APPEND_LINE/g" $GRUB_CFG
sed -i "s/$TXT_LINE/$TXT_LINE $APPEND_LINE/g" $TXT_CFG

cp "$BUILD_DIR/initrd.gz" "$TEMP_DIR"
mkdir -p "$TEMP_DIR/initrd"
(cd "$TEMP_DIR/initrd" && gunzip -c "$BUILD_DIR/initrd.gz" | cpio -id)

cat > "$TEMP_DIR/initrd/preseed.cfg" << 'EndOfMessage'
d-i debian-installer/language string en
d-i debian-installer/country string US
d-i debian-installer/locale string en_US.UTF-8

d-i netcfg/choose_interface select auto
d-i netcfg/link_wait_timeout string 1
d-i netcfg/dhcpv6_timeout string 1
d-i netcfg/dhcp_timeout string 3
d-i netcfg/hostname string hostname
d-i netcfg/get_hostname string hostname
d-i netcfg/get_domain string hostdomain

d-i mirror/country string manual
d-i mirror/http/hostname string pl.archive.ubuntu.com
d-i mirror/http/directory string /ubuntu
d-i mirror/suite string focal

d-i user-setup/allow-password-weak boolean true

# mkpasswd -m sha-512 -S $(pwgen -ns 16 1) mypassword
#d-i passwd/root-login boolean true
#d-i passwd/root-password-crypted password $6$rdp2Pq9okmQm$mrIjThChupd4A9zbT4CIk9YXbhmFPWhobNsUk7bKApMtdWxaWJDhRcbB0cXUBvxbDZGxz2uOrRa1ga/Z1a29H1
#d-i passwd/make-user boolean true
#d-i passwd/user-fullname string User
#d-i passwd/username string user
#d-i passwd/user-uid string 1001
#d-i passwd/user-default-groups string sudo
#d-i passwd/user-password-crypted password $6$rdp2Pq9okmQm$mrIjThChupd4A9zbT4CIk9YXbhmFPWhobNsUk7bKApMtdWxaWJDhRcbB0cXUBvxbDZGxz2uOrRa1ga/Z1a29H1

d-i clock-setup/utc boolean true
d-i time/zone string EU/Warsaw
d-i clock-setup/ntp boolean true
d-i clock-setup/ntp-server string 0.pl.pool.ntp.org

d-i partman-auto/init_automatically_partition select biggest_free
d-i partman-auto/method string crypto
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-auto-lvm/guided_size string max
d-i partman-auto-lvm/new_vg_name string crypt
d-i partman-auto/choose_recipe select root-encrypted
d-i partman-auto/expert_recipe string                         \
      root-encrypted ::                                       \
              1024 100 1024 ext4                              \
                      $gptonly{ }                             \
                      $primary{ } $bootable{ }                \
                      method{ format } format{ }              \
                      use_filesystem{ } filesystem{ ext4 }    \
                      mountpoint{ /boot }                     \
              .                                               \
              1024 100 1024 ext4                              \
                      $gptonly{ }                             \
                      $primary{ } $bootable{ }                \
                      method{ format } format{ }              \
                      use_filesystem{ } filesystem{ ext4 }    \
                      mountpoint{ /boot/efi }                 \
              .                                               \
              8192 150 -1 ext4                                \
                      $lvmok{ } lv_name{ root }               \
                      in_vg { crypt }                         \
                      $gptonly{ }                             \
                      $primary{ }                             \
                      method{ format } format{ }              \
                      use_filesystem{ } filesystem{ ext4 }    \
                      mountpoint{ / }                         \
              .
d-i partman/default_filesystem string ext4
d-i partman-partitioning/no_bootable_gpt_biosgrub boolean false
d-i partman-partitioning/no_bootable_gpt_efi boolean false
d-i partman-basicfilesystems/no_mount_point boolean false
d-i partman-basicfilesystems/choose_label string gpt
d-i partman-basicfilesystems/default_label string gpt
d-i partman-partitioning/choose_label string gpt
d-i partman-partitioning/default_label string gpt
d-i partman/choose_label string gpt
d-i partman/default_label string gpt
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

d-i pkgsel/updatedb boolean true
d-i pkgsel/upgrade select full-upgrade
# d-i pkgsel/include string kde-plasma-desktop ubuntu-gnome-desktop
d-i pkgsel/language-packs multiselect en, pl
d-i pkgsel/update-policy select unattended-upgrades

d-i cdrom-detect/eject boolean true
d-i finish-install/reboot_in_progress note

d-i preseed/late_command string in-target apt-get update ; \
                                in-target apt-get upgrade -y ; \
                                in-target apt-get dist-upgrade -y ; \
                                in-target apt-get install -y openssh-server build-essential lvm2 cryptsetup ; \
                                in-target apt-get install -y sudo gdebi wget perl gawk sed awk python3
#                                in-target wget https://zoom.us/client/latest/zoom_amd64.deb -O /tmp/zoom_amd64.deb ; \
#                                in-target wget https://downloads.slack-edge.com/linux_releases/slack-desktop-4.4.3-amd64.deb -O /tmp/slack-desktop-4.4.3-amd64.deb ; \
#                                in-target wget https://download.teamviewer.com/download/linux/teamviewer_amd64.deb -O /tmp/teamviewer_amd64.deb ; \
#                                in-target wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome-stable_current_amd64.deb ; \
#                                in-target dpkg -i /tmp/zoom_amd64.deb ; \
#                                in-target dpkg -i /tmp/slack-desktop-4.4.3-amd64.deb ; \
#                                in-target dpkg -i /tmp/teamviewer_amd64.deb ; \
#                                in-target dpkg -i /tmp/google-chrome-stable_current_amd64.deb ; \
#                                in-target apt-get --fix-broken install -y
EndOfMessage

chmod 644 "$TEMP_DIR/initrd/preseed.cfg"

(cd "$TEMP_DIR/initrd" && find . | cpio -o -H newC | gzip) > "$TEMP_DIR/initrd.gz"

mv "$TEMP_DIR/initrd.gz" "$BUILD_DIR"

chmod 444 "$BUILD_DIR/initrd.gz"

xorriso -as mkisofs -r -V "Custom Ubuntu" \
  -cache-inodes -J -l \
  -isohybrid-mbr "$UBUNTU_MBR" \
  -c boot.cat \
  -b isolinux.bin \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
  -e boot/grub/efi.img \
  -no-emul-boot -isohybrid-gpt-basdat \
  -o "$CUSTOM_ISO" \
  "$BUILD_DIR"

mount -o loop "$CUSTOM_ISO" "$CUSTOM_ISO_DIR"
chmod 755 "$BASE_DIR"
chmod 644 "$CUSTOM_ISO"
