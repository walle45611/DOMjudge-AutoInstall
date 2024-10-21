#!/bin/bash

# 確保以 sudo 權限執行腳本
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31mPlease run as root or with sudo\e[0m"
  exit
fi

# 分隔線函數
function print_separator {
    echo -e "\e[33m========================================\e[0m"
}

# 設置標誌文件的路徑
FLAG_FILE="/opt/domjudge/judgehost/install_flag"

# 檢查命令行參數
new_api_url=${1:-"http://localhost/domjudge/api"}
new_user=${2:-"judgehost"}
new_password=${3:-""}

# 如果 FLAG_FILE 不存在，則運行第一次安裝步驟
if [ ! -f "$FLAG_FILE" ]; then
  print_separator
  echo -e "\e[36mStarting judgehost installation...\e[0m"
  print_separator

  # 更新系統並安裝所有必要的包
  echo -e "\e[36mUpdating package lists and installing required packages...\e[0m"
  sudo apt-get update
  sudo apt-get install -y make pkg-config sudo debootstrap libcgroup-dev \
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
  ./configure --prefix=/opt/domjudge
  make judgehost
  sudo make install-judgehost
  print_separator

  # 配置 judgehost 相關文件
  echo -e "\e[36mSetting up judgehost environment...\e[0m"
  cd /opt/domjudge/judgehost/etc
  sudo useradd -d /nonexistent -U -M -s /bin/false domjudge-run
  sudo cp sudoers-domjudge /etc/sudoers.d
  print_separator

  # 設置 chroot 環境
  echo -e "\e[36mCreating chroot environment...\e[0m"
  sudo /opt/domjudge/judgehost/bin/dj_make_chroot
  print_separator

  # 更新 grub 配置以啟用 cgroup 功能
  echo -e "\e[36mConfiguring GRUB for cgroup support...\e[0m"
  sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash cgroup_enable=memory swapaccount=1 systemd.unified_cgroup_hierarchy=0"/' /etc/default/grub
  sudo update-grub
  print_separator

  # 創建標誌文件，表示已完成第一部分
  sudo touch "$FLAG_FILE"

  # 重新啟動系統
  echo -e "\e[31mRebooting the system to apply changes...\e[0m"
  print_separator
  reboot
  exit 0  # 退出腳本，等待系統重啟後繼續
fi

# 如果系統已重啟，繼續安裝第二部分
if [ -f "$FLAG_FILE" ]; then
  print_separator
  echo -e "\e[36mContinuing judgehost installation after reboot...\e[0m"
  print_separator

  # 創建 cgroups
  echo -e "\e[36mCreating cgroups...\e[0m"
  sudo /opt/domjudge/judgehost/bin/create_cgroups
  print_separator

  # 顯示已安裝的編譯器版本
  echo -e "\e[36mChecking installed compiler versions...\e[0m"
  gcc --version
  g++ --version
  javac -version
  python3 --version
  print_separator

  # 更新 REST API secret 文件
  echo -e "\e[36mUpdating REST API secret...\e[0m"
  SECRET_FILE="/opt/domjudge/judgehost/etc/restapi.secret"

  # 構建新的行
  new_line="default $new_api_url $new_user $new_password"

  # 更新文件中的 "default" 行
  sudo sed -i "s|^default.*|$new_line|" "$SECRET_FILE"

  # 輸出更新後的內容
  echo -e "\e[32mREST API secret has been updated:\e[0m"
  sudo grep '^default' "$SECRET_FILE"
  print_separator

  # 配置 judgedaemon 系統服務
  echo -e "\e[36mCreating judgedaemon systemd service...\e[0m"

  cat <<EOL | sudo tee /etc/systemd/system/judgedaemon.service > /dev/null
[Unit]
Description=DOMjudge Judgedaemon Service
After=network.target

[Service]
Type=simple
User=user
WorkingDirectory=/opt/domjudge/judgehost
ExecStart=/opt/domjudge/judgehost/bin/judgedaemon
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

  # 啟用並啟動 judgedaemon 服務
  echo -e "\e[36mEnabling and starting judgedaemon service...\e[0m"
  sudo systemctl daemon-reload
  sudo systemctl enable judgedaemon
  sudo systemctl start judgedaemon
  print_separator

  # 刪除標誌文件，表示安裝已完成
  sudo rm "$FLAG_FILE"

  # 安裝完成訊息
  echo -e "\e[31mJudgehost installation completed!\e[0m"
  print_separator
fi
