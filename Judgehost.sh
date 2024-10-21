#!/bin/bash

if [ "$EUID" -eq 0 ] && [ "$1" != "continue" ]; then
  echo -e "\e[31mPlease do not run this script as root\e[0m"
  exit
fi

function print_separator {
    echo -e "\e[33m========================================\e[0m"
}

FLAG_FILE="/opt/domjudge/judgehost/install_flag"
SECRET_FILE="/opt/domjudge/judgehost/etc/restapi.secret"
SYSTEMD_SERVICE="/etc/systemd/system/judgehost-continue-installation.service"

new_api_url=${1:-"http://localhost/domjudge/api"}
new_user=${2:-"judgehost"}
new_password=${3:-"lPtXd3VkjNdsSCnME6e0UzEZbjSpEyFi"}

if [ ! -f "$FLAG_FILE" ]; then
  print_separator
  echo -e "\e[36mStarting judgehost installation...\e[0m"
  print_separator

  echo -e "\e[36mUpdating package lists and installing required packages...\e[0m"
  sudo apt-get update
  sudo apt-get install -y make pkg-config debootstrap libcgroup-dev \
      php-cli php-curl php-json php-xml php-zip lsof procps gcc g++ \
      openjdk-8-jre-headless openjdk-8-jdk ghc fp-compiler libjsoncpp-dev build-essential
  print_separator

  echo -e "\e[36mDownloading and extracting DOMjudge...\e[0m"
  wget https://www.domjudge.org/releases/domjudge-8.3.1.tar.gz
  tar -zxf domjudge-8.3.1.tar.gz
  cd domjudge-8.3.1
  print_separator

  echo -e "\e[36mConfiguring and installing judgehost...\e[0m"
  ./configure --prefix=/opt/domjudge --with-domjudge-user=$USER
  make judgehost
  sudo make install-judgehost
  print_separator

  echo -e "\e[36mSetting up judgehost environment...\e[0m"
  cd /opt/domjudge/judgehost/etc
  sudo useradd -d /nonexistent -U -M -s /bin/false domjudge-run
  sudo cp sudoers-domjudge /etc/sudoers.d
  print_separator

  echo -e "\e[36mCreating chroot environment...\e[0m"
  sudo /opt/domjudge/judgehost/bin/dj_make_chroot
  print_separator

  echo -e "\e[36mConfiguring GRUB for cgroup support...\e[0m"
  sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash cgroup_enable=memory swapaccount=1 systemd.unified_cgroup_hierarchy=0"/' /etc/default/grub
  sudo update-grub
  print_separator

  echo "# Randomly generated on host $(hostname), $(date)" | sudo tee "$SECRET_FILE" > /dev/null
  echo "# Format: '<ID> <API url> <user> <password>'" | sudo tee -a "$SECRET_FILE" > /dev/null
  echo "default $new_api_url $new_user $new_password" | sudo tee -a "$SECRET_FILE" > /dev/null

  sudo touch "$FLAG_FILE"

  sudo bash -c "cat > $SYSTEMD_SERVICE <<EOL
[Unit]
Description=Continue Judgehost Installation After Reboot
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash $HOME/DOMjudge-AutoInstall/Judgehost.sh continue
User=root

[Install]
WantedBy=multi-user.target
EOL"

  sudo systemctl daemon-reload
  sudo systemctl enable judgehost-continue-installation


  print_separator

  echo -e "\e[36mCreating judgedaemon systemd service...\e[0m"

  cat <<EOL | sudo tee /etc/systemd/system/judgedaemon.service > /dev/null
[Unit]
Description=DOMjudge Judgedaemon Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/domjudge/judgehost
ExecStart=/opt/domjudge/judgehost/bin/judgedaemon
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

  print_separator

  echo -e "\e[31mRebooting the system to apply changes...\e[0m"

  sudo reboot
  exit 0
fi

if [ "$1" == "continue" ]; then
  if [ -f "$FLAG_FILE" ]; then
    print_separator
    echo -e "\e[36mContinuing judgehost installation after reboot...\e[0m"
    print_separator

    echo -e "\e[36mCreating cgroups...\e[0m"
    /opt/domjudge/judgehost/bin/create_cgroups
    print_separator

    echo -e "\e[36mChecking installed compiler versions...\e[0m"
    gcc --version
    g++ --version
    javac -version
    python3 --version
    print_separator

    echo -e "\e[36mEnabling and starting judgedaemon service...\e[0m"
    systemctl daemon-reload
    systemctl enable judgedaemon
    systemctl start judgedaemon
    print_separator

    sudo rm "$FLAG_FILE"

    systemctl disable judgehost-continue-installation
    sudo rm "$SYSTEMD_SERVICE"

    echo -e "\e[31mJudgehost installation completed!\e[0m"
    print_separator
  fi
fi
