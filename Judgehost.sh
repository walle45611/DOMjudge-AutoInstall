#!/bin/bash
#
# DOMjudge Judgehost 安裝腳本
#
# 這個腳本用於在 Ubuntu 上安裝並配置 DOMjudge judgehost 節點。
# 它會安裝必要的軟件包，配置 judgehost，並在需要時安裝和啟用 judgedaemon 服務。
# 第一次運行時需要普通使用者身份，不可在 root 下執行。若需要重啟後繼續安裝，
# 可以使用參數 "continue" 來完成剩餘步驟。
#
# 用法：
#   ./Judgehost.sh [continue] [<API URL> <judgehost user> <judgehost password>]
#
# 參數：
#   continue            （可選）在重啟後繼續安裝
#   <API URL>           （可選）DOMjudge API 的 URL，默認為 "http://localhost/domjudge/api"
#   <judgehost user>    （可選）Judgehost 用戶名，默認為 "judgehost"
#   <judgehost password>（可選）Judgehost 用戶密碼，默認為 "lPtXd3VkjNdsSCnME6e0UzEZbjSpEyFi"
#
# 作者：
#   Ho,Kuo-Wei
#
# 版本：
#   1.0.0 - 初版
#

# 檢查是否在 root 下運行
if [ "$EUID" -eq 0 ] && [ "$1" != "continue" ]; then
  echo -e "\e[31mPlease do not run this script as root\e[0m"
  exit
fi

# 分隔線顯示函數
function print_separator {
  echo -e "\e[33m========================================\e[0m"
}

# 安裝狀態標誌檔案
FLAG_FILE="/opt/domjudge/judgehost/install_flag"
SECRET_FILE="/opt/domjudge/judgehost/etc/restapi.secret"
SYSTEMD_SERVICE="/etc/systemd/system/judgehost-continue-installation.service"

# 判斷是否傳入 DOMjudge API URL、judgehost 使用者、密碼，否則設為默認值
new_api_url=${1:-"http://localhost/domjudge/api"}
new_user=${2:-"judgehost"}
new_password=${3:-"lPtXd3VkjNdsSCnME6e0UzEZbjSpEyFi"}

# 檢查是否第一次運行
if [ ! -f "$FLAG_FILE" ]; then
  print_separator
  echo -e "\e[36mStarting judgehost installation...\e[0m"
  print_separator

  # 更新系統並安裝必要的軟件包
  echo -e "\e[36mUpdating package lists and installing required packages...\e[0m"
  sudo apt-get update
  sudo apt-get install -y make pkg-config debootstrap libcgroup-dev \
    php-cli php-curl php-json php-xml php-zip lsof procps gcc g++ \
    openjdk-8-jre-headless openjdk-8-jdk ghc fp-compiler libjsoncpp-dev build-essential
  print_separator

  # 下載並解壓 DOMjudge
  echo -e "\e[36mDownloading and extracting DOMjudge...\e[0m"
  wget https://www.domjudge.org/releases/domjudge-8.3.1.tar.gz
  tar -zxf domjudge-8.3.1.tar.gz
  cd domjudge-8.3.1
  print_separator

  # 配置並安裝 judgehost
  echo -e "\e[36mConfiguring and installing judgehost...\e[0m"
  ./configure --prefix=/opt/domjudge --with-domjudge-user=$USER
  make judgehost
  sudo make install-judgehost
  print_separator

  # 設置 judgehost 環境
  echo -e "\e[36mSetting up judgehost environment...\e[0m"
  cd /opt/domjudge/judgehost/etc
  sudo useradd -d /nonexistent -U -M -s /bin/false domjudge-run
  sudo cp sudoers-domjudge /etc/sudoers.d
  print_separator

  # 創建 chroot 環境
  echo -e "\e[36mCreating chroot environment...\e[0m"
  sudo /opt/domjudge/judgehost/bin/dj_make_chroot
  print_separator

  # 配置 GRUB 以支持 cgroup
  echo -e "\e[36mConfiguring GRUB for cgroup support...\e[0m"
  sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash cgroup_enable=memory swapaccount=1 systemd.unified_cgroup_hierarchy=0"/' /etc/default/grub
  sudo update-grub
  print_separator

  # 配置 Rest API 密鑰
  echo "# Randomly generated on host $(hostname), $(date)" | sudo tee "$SECRET_FILE" >/dev/null
  echo "# Format: '<ID> <API url> <user> <password>'" | sudo tee -a "$SECRET_FILE" >/dev/null
  echo "default $new_api_url $new_user $new_password" | sudo tee -a "$SECRET_FILE" >/dev/null

  # 設置安裝標誌檔案
  sudo touch "$FLAG_FILE"

  # 配置重啟後繼續安裝的 systemd 服務
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

  # 創建 judgedaemon 的 systemd 服務
  echo -e "\e[36mCreating judgedaemon systemd service...\e[0m"
  cat <<EOL | sudo tee /etc/systemd/system/judgedaemon.service >/dev/null
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

# 如果第一次運行後重啟，繼續安裝
if [ "$1" == "continue" ]; then
  if [ -f "$FLAG_FILE" ]; then
    print_separator
    echo -e "\e[36mContinuing judgehost installation after reboot...\e[0m"
    print_separator

    # 創建 cgroups
    echo -e "\e[36mCreating cgroups...\e[0m"
    /opt/domjudge/judgehost/bin/create_cgroups
    print_separator

    # 檢查已安裝的編譯器版本
    echo -e "\e[36mChecking installed compiler versions...\e[0m"
    gcc --version
    g++ --version
    javac -version
    python3 --version
    print_separator

    # 啟用並啟動 judgedaemon 服務
    echo -e "\e[36mEnabling and starting judgedaemon service...\e[0m"
    systemctl daemon-reload
    systemctl enable judgedaemon
    systemctl start judgedaemon
    print_separator

    # 清理安裝標誌檔案和 systemd 配置
    sudo rm "$FLAG_FILE"
    systemctl disable judgehost-continue-installation
    sudo rm "$SYSTEMD_SERVICE"

    echo -e "\e[31mJudgehost installation completed!\e[0m"
    print_separator
  fi
fi
