#!/usr/bin/env bash
#
# Copyright by Dasandata.co.ltd
# http://www.dasandata.co.kr
#
# Modernized Version: 2025-12-23
# Target OS: Ubuntu 22.04/24.04, Rocky Linux 8/9, AlmaLinux 8/9
# OPTIMIZED: RAID/OMSA before GPU installation
#

# --- 스크립트 실행 전 확인 ---
if [ "$(id -u)" -ne 0 ]; then
  echo "이 스크립트는 root 권한으로 실행해야 합니다."
  exit 1
fi

# --- 1. 변수 선언 및 OS 탐지 ---
echo "시스템 정보 및 OS를 탐지합니다..."
VENDOR=$(dmidecode -s system-manufacturer | awk '{print$1}')
NIC=$(ip -o -4 route show to default | awk '{print $5}')

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_VERSION_MAJOR=$(echo "$VERSION_ID" | cut -d. -f1)
    OS_FULL_ID="${OS_ID}${OS_VERSION_MAJOR}"
else
    echo "OS 정보를 확인할 수 없습니다. /etc/os-release 파일이 없습니다."
    exit 1
fi

LOG_DIR="/root/dasan_LOGS"
mkdir -p "$LOG_DIR"
INSTALL_LOG="$LOG_DIR/install.log"
ERROR_LOG="$LOG_DIR/error.log"
SCRIPT_STATE_FILE="$LOG_DIR/script_state.txt"     # 스크립트 상태 추적 파일
SCRIPT_CLEANUP_FLAG="$LOG_DIR/cleanup_done.flag"  # 정리 완료 플래그

echo "스크립트 실행 로그는 $LOG_DIR 에 저장됩니다."

# --- 스크립트 상태 초기화 ---
if [ ! -f "$SCRIPT_STATE_FILE" ]; then
    echo "INITIAL" > "$SCRIPT_STATE_FILE"
fi

CURRENT_STATE=$(cat "$SCRIPT_STATE_FILE")
echo "현재 스크립트 상태: $CURRENT_STATE" | tee -a "$INSTALL_LOG"

# --- RC.LOCAL 경로 설정 (OS에 따라) ---
case "$OS_ID" in
    ubuntu)
        RC_PATH="/etc/rc.local"
        ;;
    rocky|almalinux)
        mkdir -p /etc/rc.d
        RC_PATH="/etc/rc.d/rc.local"
        ;;
    *)
        echo "지원하지 않는 OS이므로 rc.local 설정을 건너뜁니다." | tee -a "$ERROR_LOG"
        exit 1
        ;;
esac

# === 상태별 실행 로직 ===
case "$CURRENT_STATE" in
# ------------------------------------------------------------
# INITIAL 단계: 기본 설정 + RAID/OMSA 설치 + 첫 재부팅
# ------------------------------------------------------------
"INITIAL")
    echo "========== INITIAL: 초기 설정 단계 시작 ==========" | tee -a "$INSTALL_LOG"

    # --- 2. CUDA 버전 선택 ---
    if [ ! -f $LOG_DIR/cudaversion.txt ]; then
        echo "CUDA 버전 선택을 시작합니다." | tee -a "$INSTALL_LOG"
        CUDA_OPTIONS=""
        case "$OS_FULL_ID" in
            ubuntu24)
                CUDA_OPTIONS="12-8 12-9 13-0 No-GPU"
                ;;
            ubuntu22)
                CUDA_OPTIONS="11-8 12-5 12-6 12-8 12-9 13-0 No-GPU"
                ;;
            rocky8|rocky9|almalinux8|almalinux9)
                CUDA_OPTIONS="12-8 12-9 13-0 No-GPU"
                ;;
            *)
                CUDA_OPTIONS="11-8 12-5 12-6 12-8 12-9 No-GPU"
                ;;
        esac

        if [ -n "$CUDA_OPTIONS" ]; then
            PS3='설치할 CUDA 버전을 선택하세요: '
            select CUDAV in $CUDA_OPTIONS; do
                if [[ " ${CUDA_OPTIONS[*]} " =~ " ${CUDAV} " ]]; then
                    echo "선택한 CUDA 버전: $CUDAV" | tee -a "$INSTALL_LOG"
                    echo "$CUDAV" > $LOG_DIR/cudaversion.txt
                    break
                else
                    echo "잘못된 선택입니다. 다시 시도하세요."
                fi
            done
        else
            echo "No-GPU" > $LOG_DIR/cudaversion.txt
        fi
    fi

    # --- RAID 관리자 선택 ---
    if [ ! -f $LOG_DIR/raidmanager.txt ]; then
        echo "RAID 관리자 선택을 시작합니다." | tee -a "$INSTALL_LOG"
        PS3='설치할 RAID 관리자를 선택하세요: '
        options=("MSM" "LSA" "no install")
        select opt in "${options[@]}"; do
            case $opt in
                "MSM"|"LSA"|"no install")
                    echo "선택한 RAID 관리자: $opt" | tee -a "$INSTALL_LOG"
                    echo "$opt" > $LOG_DIR/raidmanager.txt
                    break
                    ;;
                *)
                    echo "잘못된 선택입니다. 1, 2, 3 중 하나를 입력하세요."
                    ;;
            esac
        done
    fi

    # --- 3. rc.local 설정 ---
    echo "rc.local 설정을 시작합니다." | tee -a "$INSTALL_LOG"

    # rc.local 파일이 없다면 기본 틀 생성
    if [ ! -f "$RC_PATH" ]; then
        echo "#!/bin/sh -e" > "$RC_PATH"
        echo "" >> "$RC_PATH"
        echo "exit 0" >> "$RC_PATH"
    fi

    # 스크립트 실행 명령이 파일 내에 없는 경우 추가
    SCRIPT_EXEC_CMD="bash /root/LAS/Linux_Auto_Script.sh"
    if ! grep -Fq "$SCRIPT_EXEC_CMD" "$RC_PATH"; then
        echo "스크립트 실행 명령을 $RC_PATH 에 추가합니다." | tee -a "$INSTALL_LOG"
        if grep -q "^exit 0" "$RC_PATH"; then
            sed -i '/^exit 0/i '"$SCRIPT_EXEC_CMD"'\n' "$RC_PATH"
        else
            echo -e "\n$SCRIPT_EXEC_CMD" >> "$RC_PATH"
        fi
    fi

    chmod +x "$RC_PATH"

    # rc.local을 위한 systemd 서비스 파일 생성 (수정됨)
    RC_SERVICE_FILE="/etc/systemd/system/rc-local.service"
    if [ ! -f "$RC_SERVICE_FILE" ]; then
        cat <<EOF > "$RC_SERVICE_FILE"
[Unit]
Description=/etc/rc.local Compatibility
After=network.target

[Service]
Type=oneshot
ExecStart=$RC_PATH
TimeoutSec=0
StandardOutput=tty
StandardError=tty
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
    fi

    if ! systemctl is-enabled --quiet rc-local.service; then
        systemctl enable rc-local.service >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
    fi

    echo "rc.local 설정 완료." | tee -a "$INSTALL_LOG"

    # --- 4. Nouveau 비활성화 및 GRUB 설정 ---
    if lsmod | grep -q "^nouveau"; then
        echo "Nouveau 드라이버 비활성화 및 GRUB 설정을 시작합니다." | tee -a "$INSTALL_LOG"

        echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nouveau.conf
        echo "options nouveau modeset=0" >> /etc/modprobe.d/blacklist-nouveau.conf

        case "$OS_ID" in
            ubuntu)
                update-initramfs -u >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                update-grub >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                ;;
            rocky|almalinux)
                dracut -f >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                grub2-mkconfig -o /boot/grub2/grub.cfg >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                if [ -f /boot/efi/EFI/"$OS_ID"/grub.cfg ]; then
                    grub2-mkconfig -o /boot/efi/EFI/"$OS_ID"/grub.cfg >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                fi
                ;;
        esac

        echo "GRUB 설정 완료. 재부팅 후 적용됩니다." | tee -a "$INSTALL_LOG"
    fi

    # --- 5. 시스템 설정 (SELinux, Repository) ---  ← 4번: 요청대로 내용 유지
    echo "시스템 설정을 시작합니다." | tee -a "$INSTALL_LOG"
    case "$OS_ID" in
        rocky|almalinux)
            if sestatus | grep -q "enabled"; then
                echo "SELinux를 disabled로 변경합니다." | tee -a "$INSTALL_LOG"
                setenforce 0
                sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
            fi
            ;;
        ubuntu)
            case "$OS_FULL_ID" in
                ubuntu24)
                    echo "Ubuntu 24.04 APT 저장소를 mirror.kakao.com으로 변경합니다." | tee -a "$INSTALL_LOG"
                    UBUNTU_SRC_FILE="/etc/apt/sources.list.d/ubuntu.sources"
                    if [ -f "$UBUNTU_SRC_FILE" ]; then
                        sed -i 's|http://kr.archive.ubuntu.com/ubuntu/|http://mirror.kakao.com/ubuntu/|g' "$UBUNTU_SRC_FILE"
                        sed -i 's|http://security.ubuntu.com/ubuntu/|http://mirror.kakao.com/ubuntu/|g' "$UBUNTU_SRC_FILE"
                    fi
                    ;;
                ubuntu20|ubuntu22)
                    echo "Ubuntu $OS_VERSION_MAJOR.04 APT 저장소를 mirror.kakao.com으로 변경합니다." | tee -a "$INSTALL_LOG"
                    sed -i 's|kr.archive.ubuntu.com|mirror.kakao.com|g' /etc/apt/sources.list
                    sed -i 's|security.ubuntu.com|mirror.kakao.com|g' /etc/apt/sources.list
                    ;;
            esac
            apt-get update >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            ;;
    esac
    echo "시스템 설정 완료." | tee -a "$INSTALL_LOG"

    # --- 6. 기본 패키지 설치 ---
    echo "기본 패키지 설치를 시작합니다." | tee -a "$INSTALL_LOG"
    export DEBIAN_FRONTEND=noninteractive

    case "$OS_FULL_ID" in
        ubuntu20|ubuntu22|ubuntu24)
            apt-get -y install build-essential snapd firefox vim nfs-common rdate xauth curl git wget figlet net-tools htop >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            apt-get -y install util-linux-extra smartmontools tmux xfsprogs aptitude lvm2 dstat ntfs-3g >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            apt-get -y install gnome-tweaks ubuntu-desktop dconf-editor gnome-settings-daemon metacity nautilus gnome-terminal >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            apt-get -y install ntfs-3g ipmitool python3-pip python3-dev >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            apt-get -y install npm >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            ;;
        rocky8|rocky9|almalinux8|almalinux9)
            dnf -y install epel-release >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            dnf -y groupinstall "Server with GUI" "Development Tools" >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            dnf -y install ethtool pciutils openssh mlocate nfs-utils xauth firefox nautilus wget bind-utils >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            dnf -y install tcsh tree lshw tmux kernel-headers kernel-devel gcc make gcc-c++ yum-utils >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            dnf -y install cmake dstat perl perl-CPAN perl-core net-tools openssl-devel git-lfs vim >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            dnf -y install git bash-completion smartmontools ipmitool tar chrony htop ntfs-3g >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            ;;
    esac
    echo "기본 패키지 설치 완료." | tee -a "$INSTALL_LOG"

    # --- 7. 프로필(alias, history, 프롬프트 등) 설정 ---
    echo "프로필(alias 및 히스토리, 프롬프트) 설정을 시작합니다." | tee -a "$INSTALL_LOG"

    if ! grep -q "Dasandata" /etc/profile; then
        {
            echo ""
            echo "# Add by Dasandata"
            echo "alias vi='vim'"
            echo "alias ls='ls --color=auto'"
            echo "alias ll='ls -lh'"
            echo "alias grep='grep --color=auto'"
            echo ""
            echo "# Add Timestamp to .bash_history"
            echo 'export HISTTIMEFORMAT="20%y/%m/%d %T "'
        } >> /etc/profile

        echo "export PS1='\[\e[1;46;30m\][\u@\h:\W]\\$\[\e[m\] '" >> /root/.bashrc

        # 즉시 반영
        # shellcheck disable=SC1091
        source /etc/profile
        # shellcheck disable=SC1091
        source /root/.bashrc

        echo "프로필 설정 완료." | tee -a "$INSTALL_LOG"
    fi

    # --- 8. 서버 시간 동기화 ---
    echo "서버 시간 동기화 설정을 시작합니다." | tee -a "$INSTALL_LOG"
    TIME_LOG="$LOG_DIR/Time_Setting_log.txt"
    TIME_ERR="$LOG_DIR/Time_Setting_log_err.txt"

    case "$OS_FULL_ID" in
        rocky8|rocky9|almalinux8|almalinux9)
            dnf -y install chrony >> "$TIME_LOG" 2>> "$TIME_ERR"
            sed -i 's|^server .*iburst|server kr.pool.ntp.org iburst|' /etc/chrony.conf
            systemctl enable --now chronyd >> "$TIME_LOG" 2>> "$TIME_ERR"
            timedatectl set-timezone Asia/Seoul >> "$TIME_LOG" 2>> "$TIME_ERR"
            chronyc makestep >> "$TIME_LOG" 2>> "$TIME_ERR"
            hwclock --systohc >> "$TIME_LOG" 2>> "$TIME_ERR"
            ;;
        ubuntu20|ubuntu22|ubuntu24)
            apt-get -y install chrony >> "$TIME_LOG" 2>> "$TIME_ERR"
            sed -i 's|^pool .* iburst|pool kr.pool.ntp.org iburst|' /etc/chrony/chrony.conf
            systemctl enable --now chrony >> "$TIME_LOG" 2>> "$TIME_ERR"
            timedatectl set-timezone Asia/Seoul >> "$TIME_LOG" 2>> "$TIME_ERR"
            chronyc makestep >> "$TIME_LOG" 2>> "$TIME_ERR"
            hwclock --systohc >> "$TIME_LOG" 2>> "$TIME_ERR"
            ;;
    esac

    echo "서버 시간 동기화 설정 완료." | tee -a "$INSTALL_LOG"

    # --- 9. Python & pip 설치 ---
    echo "Python 3 및 pip 설치를 시작합니다." | tee -a "$INSTALL_LOG"
    if ! command -v pip3 &>/dev/null; then
        case "$OS_FULL_ID" in
            rocky8|rocky9|almalinux8|almalinux9)
                dnf -y install python3 python3-pip >> "$LOG_DIR/Python_install.log" 2>> "$LOG_DIR/Python_install_log_err.txt"
                ;;
            ubuntu20|ubuntu22|ubuntu24)
                apt-get update >> "$LOG_DIR/Python_install.log" 2>> "$LOG_DIR/Python_install_log_err.txt"
                apt-get -y install python3 python3-pip >> "$LOG_DIR/Python_install.log" 2>> "$LOG_DIR/Python_install_log_err.txt"
                ;;
        esac
        python3 -m pip install --upgrade pip >> "$LOG_DIR/Python_install.log" 2>> "$LOG_DIR/Python_install_log_err.txt"
    fi
    echo "Python 3 및 pip 설치 완료" | tee -a "$INSTALL_LOG"

    # --- 10. 방화벽 설정 (공용 포트만) ---
    echo "방화벽 설정을 시작합니다." | tee -a "$INSTALL_LOG"
    case "$OS_ID" in
        ubuntu)
            if ufw status | grep -q "Status: inactive"; then
                yes | ufw enable >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            fi
            if ufw status | grep -q "Status: active"; then
                ufw allow 22/tcp   >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                ufw allow 7777/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                ufw allow 8000/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                ufw allow 8787/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                # 1311, 2463 은 LSA/OMSA 설치 블록에서 처리
                sed -i 's/#Port 22/Port 7777/g' /etc/ssh/sshd_config
                sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
                echo "AddressFamily inet" >> /etc/ssh/sshd_config
            fi
            ;;
        rocky|almalinux)
            if ! systemctl is-active --quiet firewalld; then
                systemctl enable --now firewalld >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            fi
            if systemctl is-active --quiet firewalld; then
                firewall-cmd --permanent --add-port=22/tcp   >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                firewall-cmd --permanent --add-port=7777/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                firewall-cmd --permanent --add-port=8000/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                firewall-cmd --permanent --add-port=8787/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                # 1311, 2463 은 LSA/OMSA 설치 블록에서 처리
                firewall-cmd --reload >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                sed -i 's/#Port 22/Port 7777/g' /etc/ssh/sshd_config
                sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
                systemctl restart sshd
            fi
            ;;
    esac
    echo "방화벽 설정 완료." | tee -a "$INSTALL_LOG"

    systemctl set-default multi-user.target

    # --- 11. H/W 사양 체크 ---
    if [ ! -f $LOG_DIR/HWcheck.txt ]; then
        echo "===== H/W Check Start =====" | tee -a "$INSTALL_LOG"
        touch $LOG_DIR/HWcheck.txt

        {
            echo "############################################################"
            echo "#               H/W SPECIFICATION CHECK RESULT             #"
            echo "############################################################"
            echo ""

            echo "==================== [ System Information ] ===================="
            dmidecode --type system | grep -v "^$\|#\|SMBIOS\|Handle\|Not"
            echo ""

            echo "==================== [ CPU Information ] ===================="
            lscpu | grep -v "Flags\|NUMA|Vulnerability"
            echo ""

            echo "==================== [ Memory Devices ] ===================="
            dmidecode --type 16 | grep -v "dmidecode\|SMBIOS\|Handle"
            echo ""
            dmidecode --type memory | grep "Number Of Devices\|Size\|Locator\|Clock\|DDR\|Rank" | grep -v "No\|Unknown"
            echo ""
            echo "MemTotal from /proc/meminfo:"
            grep MemTotal /proc/meminfo
            echo ""
            echo "Free/Used Memory:"
            free -h
            echo ""

            echo "==================== [ PCIe Devices ] ===================="
            echo "VGA:"
            lspci | grep -i vga
            echo ""
            echo "NVIDIA:"
            lspci | grep -i nvidia
            echo ""
            echo "NIC (dmidecode):"
            dmidecode | grep NIC
            lspci | grep -i eth
            echo ""

            echo "==================== [ Power Supply Units ] ===================="
            dmidecode --type 39 | grep "System\|Name:\|Capacity"
            echo ""

            echo "==================== [ Disk & Partitions ] ===================="
            blkid
            lsblk
            echo ""

            echo "==================== [ OS Release & Kernel ] ===================="
            uname -a
            echo ""

            echo "############################################################"
            echo "#                  H/W CHECK END                           #"
            echo "############################################################"
        } > $LOG_DIR/HWcheck.txt

        echo "===== H/W Check Complete =====" | tee -a "$INSTALL_LOG"
    fi

    # --- 12. RAID 관리자 설치 (LSA 또는 MSM) ---
    echo "RAID 관리자 설치를 시작합니다." | tee -a "$INSTALL_LOG"
    RAID_MANAGER_CHOICE=$(cat $LOG_DIR/raidmanager.txt 2>/dev/null)

    if [ "$RAID_MANAGER_CHOICE" = "LSA" ]; then
        echo "===== LSA 설치 시작 =====" | tee -a "$INSTALL_LOG"

        mkdir -p /root/LSA_INSTALL
        cd /root/LSA_INSTALL

        wget https://docs.broadcom.com/docs-and-downloads/008.012.007.000_MR7.32_LSA_Linux.zip \
            >> "$INSTALL_LOG" 2>> "$ERROR_LOG"

        unzip -o 008.012.007.000_MR7.32_LSA_Linux.zip >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        cd webgui_rel
        unzip -o LSA_Linux.zip >> "$INSTALL_LOG" 2>> "$ERROR_LOG"

        cd gcc_8.3.x
        case "$OS_ID" in
            rocky|almalinux)
                if [ -f install.sh ]; then
                    yes | ./install.sh -s >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                    echo "Rocky/AlmaLinux: install.sh 실행 완료" | tee -a "$INSTALL_LOG"
                else
                    echo "[WARN] install.sh 파일이 없습니다." | tee -a "$INSTALL_LOG"
                fi
                ;;
            ubuntu)
                if [ -f install_deb.sh ]; then
                    yes | ./install_deb.sh -s >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                    echo "Ubuntu: install_deb.sh 실행 완료" | tee -a "$INSTALL_LOG"
                else
                    echo "[WARN] install_deb.sh 파일이 없습니다." | tee -a "$INSTALL_LOG"
                fi
                ;;
            *)
                echo "[WARN] 지원하지 않는 OS: $OS_ID" | tee -a "$INSTALL_LOG"
                ;;
        esac

        cd /root
        mkdir -p /etc/lsisash
        mv /etc/init.d/LsiSASH /etc/lsisash/LsiSASH 2>/dev/null
        chmod +x /etc/lsisash/LsiSASH 2>/dev/null

        case "$OS_FULL_ID" in
            rocky8|rocky9|almalinux8|almalinux9)
                firewall-cmd --zone=public --add-service=http --permanent >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                firewall-cmd --zone=public --add-port=2463/tcp --permanent >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                firewall-cmd --reload >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                ;;
            ubuntu20|ubuntu22|ubuntu24)
                ufw allow http  >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                ufw allow 2463/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                ;;
        esac

        SYSTEMD_FILE="/etc/systemd/system/lsisash.service"
        if [ ! -f "$SYSTEMD_FILE" ]; then
            cat <<EOF > "$SYSTEMD_FILE"
[Unit]
Description=Start LsiSASH service at boot
After=network.target

[Service]
Type=forking
ExecStart=/etc/lsisash/LsiSASH start
ExecStop=/etc/lsisash/LsiSASH stop
Restart=on-failure
TimeoutStopSec=30s

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
            systemctl enable lsisash.service >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            systemctl start lsisash.service  >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            echo "lsisash.service 서비스 등록 및 시작 완료" | tee -a "$INSTALL_LOG"
        fi

        rm -rf /root/LSA_INSTALL
        echo "===== LSA 설치 완료 =====" | tee -a "$INSTALL_LOG"

    elif [ "$RAID_MANAGER_CHOICE" = "MSM" ]; then
        echo "===== MSM 설치 시작 =====" | tee -a "$INSTALL_LOG"

        mkdir -p /tmp/raid_manager
        cd /tmp/raid_manager

        wget https://docs.broadcom.com/docs-and-downloads/raid-controllers/raid-controllers-common-files/17.05.00.02_Linux-64_MSM.gz \
            >> "$INSTALL_LOG" 2>> "$ERROR_LOG"

        case "$OS_ID" in
            ubuntu)
                tar xzf 17.05.00.02_Linux-64_MSM.gz >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                cd /tmp/raid_manager/disk
                apt-get -y install alien >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                alien --scripts *.rpm >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                dpkg --install lib-utils2_1.00-9_all.deb >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                dpkg --install megaraid-storage-manager_17.05.00-3_all.deb >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                ;;
            rocky|almalinux)
                tar xvzf 17.05.00.02_Linux-64_MSM.gz >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                cd /tmp/raid_manager/disk/ && yes | ./install.csh -a >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                ;;
        esac

        systemctl daemon-reload
        systemctl start vivaldiframeworkd.service  >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        systemctl enable vivaldiframeworkd.service >> "$INSTALL_LOG" 2>> "$ERROR_LOG"

        cd /root
        rm -rf /tmp/raid_manager

        echo "===== MSM 설치 완료 =====" | tee -a "$INSTALL_LOG"
    else
        echo "RAID 관리자를 설치하지 않습니다." | tee -a "$INSTALL_LOG"
    fi

    # --- 13. Dell OMSA install ---
    echo "OMSA 설치를 시작합니다." | tee -a "$INSTALL_LOG"

    if ! systemctl is-active --quiet dsm_om_connsvc; then
        case "$OS_FULL_ID" in
            rocky8|rocky9|almalinux8|almalinux9)
                echo "RHEL 계열 OMSA 설치" | tee -a "$INSTALL_LOG"
                firewall-cmd --permanent --add-port=1311/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                firewall-cmd --reload >> "$INSTALL_LOG" 2>> "$ERROR_LOG"

                wget http://linux.dell.com/repo/hardware/dsu/bootstrap.cgi -O ./dellomsainstall.sh \
                    >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                sed -i -e "s/enabled=1/enabled=0/g" ./dellomsainstall.sh
                yes | bash ./dellomsainstall.sh >> "$INSTALL_LOG" 2>> "$ERROR_LOG"

                dnf config-manager --set-enabled crb >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                dnf -y install --enablerepo=dell-system-update_dependent srvadmin-all openssl-devel srvadmin-idrac \
                    >> "$INSTALL_LOG" 2>> "$ERROR_LOG"

                systemctl daemon-reload
                systemctl enable dsm_om_connsvc       >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                systemctl enable dsm_sa_datamgrd.service >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                ;;
            ubuntu20|ubuntu22|ubuntu24)
                echo "Ubuntu 계열 OMSA 설치" | tee -a "$INSTALL_LOG"
                ufw allow 1311/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG"

                echo 'deb http://linux.dell.com/repo/community/openmanage/10300/focal focal main' \
                    > /etc/apt/sources.list.d/linux.dell.com.sources.list
                wget http://linux.dell.com/repo/pgp_pubkeys/0x1285491434D8786F.asc \
                    >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                apt-key add 0x1285491434D8786F.asc \
                    >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                apt-get -y update >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                pip install --upgrade pyOpenSSL cryptography >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                apt-get -y install srvadmin-all srvadmin-idrac >> "$INSTALL_LOG" 2>> "$ERROR_LOG"

                systemctl daemon-reload
                systemctl enable dsm_sa_datamgrd.service >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                systemctl enable dsm_om_connsvc         >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                ;;
        esac
    else
        echo "OMSA가 이미 설치되어 있습니다." | tee -a "$INSTALL_LOG"
    fi

    echo "OMSA 설치 완료." | tee -a "$INSTALL_LOG"
    echo "========== INITIAL 단계 완료, 첫 번째 재부팅 ==========" | tee -a "$INSTALL_LOG"

    echo "FIRST_REBOOT" > "$SCRIPT_STATE_FILE"
    sleep 3
    reboot
    ;;

# ------------------------------------------------------------
# FIRST_REBOOT 단계: GPU/IPMI 확인 후 GPU_SETUP 또는 COMPLETE
# ------------------------------------------------------------
"FIRST_REBOOT")
    echo "========== FIRST_REBOOT: 첫 번째 재부팅 후 처리 시작 ==========" | tee -a "$INSTALL_LOG"

    if ! lspci | grep -iq nvidia; then
        echo "GPU가 감지되지 않았습니다. CPU 서버로 처리합니다." | tee -a "$INSTALL_LOG"
        if ! dmidecode | grep -iq ipmi; then
            echo "IPMI가 없는 CPU 서버입니다. 바로 COMPLETE로 전환합니다." | tee -a "$INSTALL_LOG"
            systemctl set-default graphical.target >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            echo "COMPLETE" > "$SCRIPT_STATE_FILE"
        else
            echo "IPMI가 있는 서버입니다. GPU 설정 단계(GPU_SETUP)로 이동합니다." | tee -a "$INSTALL_LOG"
            echo "GPU_SETUP" > "$SCRIPT_STATE_FILE"
        fi
    else
        echo "GPU가 감지되었습니다. GPU_SETUP 단계로 이동합니다." | tee -a "$INSTALL_LOG"
        echo "GPU_SETUP" > "$SCRIPT_STATE_FILE"
    fi

    echo "두 번째 재부팅을 수행합니다." | tee -a "$INSTALL_LOG"
    sleep 3
    reboot
    ;;

# ------------------------------------------------------------
# GPU_SETUP 단계: CUDA/CUDNN 설치 후 COMPLETE로 이동
# ------------------------------------------------------------
"GPU_SETUP")
    echo "========== GPU_SETUP: GPU 설정 단계 시작 ==========" | tee -a "$INSTALL_LOG"

    CUDAV=$(cat $LOG_DIR/cudaversion.txt 2>/dev/null)

    if [ -z "$CUDAV" ] || [ "$CUDAV" = "No-GPU" ]; then
        echo "CUDA 버전이 설정되지 않았거나 No-GPU로 설정되어 GPU 설정을 스킵합니다." | tee -a "$INSTALL_LOG"
    else
        # --- 14. CUDA, CUDNN Repo install ---
        echo "CUDA 저장소 설치를 시작합니다." | tee -a "$INSTALL_LOG"

        ls /usr/local/ | grep cuda &> /dev/null
        if [ $? != 0 ]; then
            case $OS_FULL_ID in
                rocky8)
                    dnf config-manager --add-repo \
                        https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo \
                        >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
                    dnf -y install libXi-devel mesa-libGLU-devel libXmu-devel libX11-devel freeglut-devel libXm* openmotif* \
                        >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
                    ;;
                rocky9|almalinux8|almalinux9)
                    dnf config-manager --add-repo \
                        https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo \
                        >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
                    dnf -y install libXi-devel mesa-libGLU-devel libXmu-devel libX11-devel freeglut-devel libXm* openmotif* \
                        >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
                    ;;
                ubuntu20|ubuntu22|ubuntu24)
                    apt-get -y install sudo gnupg \
                        >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
                    # CUDA APT repo 등록 (Ubuntu)
                    apt-key adv --fetch-keys \
                        "https://developer.download.nvidia.com/compute/cuda/repos/${OS_FULL_ID}04/x86_64/3bf863cc.pub" \
                        >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
                    sh -c 'echo "deb https://developer.download.nvidia.com/compute/cuda/repos/'${OS_FULL_ID}04'/x86_64 /" \
                        > /etc/apt/sources.list.d/nvidia-cuda.list' \
                        >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
                    apt-get update >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
                    ;;
            esac
        else
            echo "CUDA repo가 이미 구성되어 있습니다." | tee -a "$INSTALL_LOG"
        fi

        # --- 15. CUDA install ---
        echo "CUDA 설치를 시작합니다." | tee -a "$INSTALL_LOG"
        ls /usr/local/ | grep cuda >> $LOG_DIR/install.log 2>> $LOG_DIR/log_err.txt
        if [ $? != 0 ]; then
            CUDAV_U="${CUDAV/-/.}"
            case $OS_FULL_ID in
                rocky8|rocky9|almalinux8|almalinux9)
                    if ! grep -q "ADD Cuda" /etc/profile; then
                        echo "" >> /etc/profile
                        echo "### ADD Cuda $CUDAV_U PATH" >> /etc/profile
                        echo "export PATH=/usr/local/cuda-$CUDAV_U/bin:/usr/local/cuda-$CUDAV_U/include:\$PATH" >> /etc/profile
                        echo "export LD_LIBRARY_PATH=/usr/local/cuda-$CUDAV_U/lib64:/usr/local/cuda/extras/CUPTI/:\$LD_LIBRARY_PATH" >> /etc/profile
                        echo "export CUDA_HOME=/usr/local/cuda-$CUDAV_U" >> /etc/profile
                    fi
                    dnf -y install cuda-"$CUDAV" >> $LOG_DIR/cuda_cudnn_install.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
                    nvidia-smi -pm 1 >> $LOG_DIR/cuda_cudnn_install.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
                    systemctl enable nvidia-persistenced >> $LOG_DIR/cuda_cudnn_install.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
                    # shellcheck disable=SC1091
                    source /etc/profile
                    ;;
                ubuntu20|ubuntu22|ubuntu24)
                    if ! grep -q "ADD Cuda" /etc/profile; then
                        echo "" >> /etc/profile
                        echo "### ADD Cuda $CUDAV_U PATH" >> /etc/profile
                        echo "export PATH=/usr/local/cuda-$CUDAV_U/bin:/usr/local/cuda-$CUDAV_U/include:\$PATH" >> /etc/profile
                        echo "export LD_LIBRARY_PATH=/usr/local/cuda-$CUDAV_U/lib64:/usr/local/cuda/extras/CUPTI/:\$LD_LIBRARY_PATH" >> /etc/profile
                        echo "export CUDA_HOME=/usr/local/cuda-$CUDAV_U" >> /etc/profile
                    fi
                    apt-get -y install cuda-"$CUDAV" >> $LOG_DIR/cuda_cudnn_install.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
                    ubuntu-drivers autoinstall >> $LOG_DIR/cuda_cudnn_install.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
                    nvidia-smi -pm 1 >> $LOG_DIR/cuda_cudnn_install.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
                    systemctl enable nvidia-persistenced >> $LOG_DIR/cuda_cudnn_install.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
                    # shellcheck disable=SC1091
                    source /etc/profile
                    ;;
            esac
            echo "CUDA $CUDAV 설치 완료" | tee -a "$INSTALL_LOG"
        else
            echo "CUDA가 이미 설치되어 있습니다." | tee -a "$INSTALL_LOG"
        fi

        # --- 16. CUDNN 설치 ---
        echo "CUDNN 설치를 시작합니다." | tee -a "$INSTALL_LOG"
        if [[ "$CUDAV" == *"-"* ]]; then
            CUDA_MAJOR=${CUDAV%%-*}
        else
            CUDA_MAJOR=$CUDAV
        fi

        case "$OS_FULL_ID" in
            rocky8|rocky9|almalinux8|almalinux9)
                dnf -y install \
                    cudnn9-cuda-"${CUDA_MAJOR}" \
                    libcudnn9-devel-cuda-"${CUDA_MAJOR}" \
                    >> $LOG_DIR/cuda_cudnn_install.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
                ;;
            ubuntu20|ubuntu22|ubuntu24)
                apt-get -y install \
                    libcudnn9-cuda-"${CUDA_MAJOR}" \
                    libcudnn9-dev-cuda-"${CUDA_MAJOR}" \
                    >> $LOG_DIR/cuda_cudnn_install.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
                ;;
        esac
        echo "CUDNN 설치 완료" | tee -a "$INSTALL_LOG"
    fi

    echo "GPU 설정이 완료되었습니다." | tee -a "$INSTALL_LOG"
    echo "COMPLETE" > "$SCRIPT_STATE_FILE"
    touch "$SCRIPT_CLEANUP_FLAG"

    echo "최종 재부팅을 수행합니다." | tee -a "$INSTALL_LOG"
    sleep 3
    reboot
    ;;

# ------------------------------------------------------------
# COMPLETE 단계: rc.local 정리 후 종료
# ------------------------------------------------------------
"COMPLETE")
    echo "========== COMPLETE: 최종 정리 단계 시작 ==========" | tee -a "$INSTALL_LOG"

    SCRIPT_EXEC_CMD="bash /root/LAS/Linux_Auto_Script.sh"

    if grep -Fq "$SCRIPT_EXEC_CMD" "$RC_PATH"; then
        echo "rc.local에서 메인 스크립트 실행 명령을 제거합니다." | tee -a "$INSTALL_LOG"
        sed -i '\|'"$SCRIPT_EXEC_CMD"'|d' "$RC_PATH"
        echo "제거 완료: $RC_PATH" | tee -a "$INSTALL_LOG"
    else
        echo "메인 스크립트가 이미 rc.local에서 제거되어 있습니다." | tee -a "$INSTALL_LOG"
    fi

    CHECK_SCRIPT_CMD="bash /root/LAS/Check_List.sh"
    if [ -f /root/LAS/Check_List.sh ]; then
        if ! grep -Fq "$CHECK_SCRIPT_CMD" "$RC_PATH"; then
            echo "$CHECK_SCRIPT_CMD" >> "$RC_PATH"
            chmod +x /root/LAS/Check_List.sh
            echo "다음 부팅 시 Check_List.sh를 실행하도록 등록했습니다." | tee -a "$INSTALL_LOG"
        fi
    fi

    echo "========== 모든 설정 완료. 스크립트 종료 ==========" | tee -a "$INSTALL_LOG"
    echo "필요 시 'reboot' 명령으로 시스템을 재부팅하십시오." | tee -a "$INSTALL_LOG"

    exit 0
    ;;

*)
    echo "알 수 없는 상태: $CURRENT_STATE" | tee -a "$ERROR_LOG"
    echo "INITIAL" > "$SCRIPT_STATE_FILE"
    exit 1
    ;;
esac
