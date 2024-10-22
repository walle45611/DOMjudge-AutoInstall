# DOMjudge Judgehost 快速安裝指南

此指南說明如何快速安裝並啟用 DOMjudge 的 DOMServer 和 Judgehost，適用於 HTTP（S） 設定。

## 系統需求

- Ubuntu 18.04 或更新版本

## DOMServer 腳本使用方式

1. 首先，Clone 專案並進入專案目錄：

    ```bash
    git clone https://github.com/walle45611/DOMjudge-AutoInstall.git
    cd DOMjudge-AutoInstall
    chmod +x DOMServer.sh
    ```

2. 執行 Script

    此階段最後會輸出 `judgehost password` 和 `admin password`

   ```bash
   ./install_domjudge.sh [ssl] <MariaDB root 密碼> [<SSL 證書> <SSL 私鑰>]
   ```

### Judgehost 腳本使用方式

1. 首先，Clone 專案並進入專案目錄：

    ```bash
    git clone https://github.com/walle45611/DOMjudge-AutoInstall.git
    cd DOMjudge-AutoInstall
    chmod +x Judgehost.sh
    ```

2. 執行 Script

    記得不能使用 root 執行該 Script，且要在該指定目錄執行由上述

    ```bash
    ./Judgehost.sh [continue] [<API URL> <judgehost user> <judgehost password>]
    ```

## VM 使用說明

### 使用 VMware NAT 模式

在安裝 DOMjudge 系統時，我們會使用 **VMware NAT 模式** 來確保虛擬機可以訪問外部網路，同時保持與主機的隔離。請根據以下步驟設定您的虛擬網路。

### 設定 IP 地址

在 VMware 中，請確保 DOMServer 和 Judgehost 的網路都設定為 **NAT** 模式，並使用靜態 IP：

- **DOMServer**：192.168.1.2
- **Judgehost-1**：192.168.1.3

### 設定 Port Forwarding

為了讓外部（例如您的主機）可以訪問虛擬機內的服務，需要在 VMware 中設定 **Port Forwarding**。以下是如何設定的方法：

1. **進入 VMware 虛擬網路編輯器**：
   - 打開 VMware，點擊 "Edit"（編輯），選擇 "Virtual Network Editor"（虛擬網路編輯器）。

2. **選擇 NAT 設定**：
   - 在虛擬網路編輯器中，選擇與您的虛擬機對應的 NAT 網路（例如 `VMnet8`），然後點擊 "NAT Settings"（NAT 設定）。

3. **添加 Port Forwarding 規則**：
   - 在 NAT 設定中，點擊 "Add..."（添加）以添加新的 Port Forwarding 規則。
   - 添加以下規則來轉發：

        | 描述            | 主機端口 | 虛擬機 IP 地址 | 虛擬機端口 |
        | --------------- | -------- | -------------- | ---------- |
        | DOMServer HTTP  | 89       | 192.168.1.2    | 80         |
        | DOMServer HTTPS | 443      | 192.168.1.3    | 443        |

### 4. 驗證網路設定

完成設定後，您可以通過以下方式驗證網路是否設置成功：

- 在主機中打開瀏覽器，輸入 `http://192.168.1.2:8080` 應該可以訪問 DOMServer 的管理介面。
