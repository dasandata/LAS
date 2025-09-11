#!/usr/bin/env bash
#
# Copyright by Dasandata.co.ltd
# http://www.dasandata.co.kr
#
# Modernized Version: 2025-07-10
# Target OS: Ubuntu 22.04/24.04, Rocky Linux 8/9, AlmaLinux 9
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
    echo "OS 정보를 확인할 수 없습니다. /etc/os-release 파일이 없습니다." | tee -a $LOG_DIR/install_.log
    exit 1
fi

LOG_DIR="/root/dasan_LOGS"
mkdir -p "$LOG_DIR"
INSTALL_LOG="$LOG_DIR/install.log"
ERROR_LOG="$LOG_DIR/error.log"

echo "스크립트 실행 로그는 $LOG_DIR 에 저장됩니다."

# --- 2. CUDA 버전 선택 ---
if [ ! -f $LOG_DIR/cudaversion.txt ]; then
    echo "CUDA 버전 선택을 시작합니다." | tee -a "$INSTALL_LOG"
    CUDA_OPTIONS=""
    case "$OS_FULL_ID" in
        ubuntu24)
            CUDA_OPTIONS="12-5 12-6 12-8 12-9 No-GPU"
            ;;
        ubuntu22)
            CUDA_OPTIONS="11-8 12-5 12-6 12-8 12-9 No-GPU"
            ;;
        rocky9|almalinux9)
            CUDA_OPTIONS="12-5 12-6 12-8 12-9 No-GPU"
            ;;
        rocky8)
            CUDA_OPTIONS="11-8 12-5 12-6 12-8 12-9 No-GPU"
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
        echo "지원되는 OS가 아니므로 CUDA 버전을 선택할 수 없습니다." | tee -a "$INSTALL_LOG"
        echo "No-GPU" > $LOG_DIR/cudaversion.txt
    fi
    echo "CUDA 버전 선택 완료." | tee -a "$INSTALL_LOG"
else
    echo "CUDA 버전이 이미 선택되었습니다." | tee -a "$INSTALL_LOG"
fi

# --- 3. 부팅 스크립트(rc.local) 설정 ---
echo "rc.local 설정을 시작합니다." | tee -a "$INSTALL_LOG"
# OS에 따라 rc.local 경로 설정
case "$OS_ID" in
    ubuntu)
        RC_PATH="/etc/rc.local"
        ;;
    rocky|almalinux)
        mkdir -p /etc/rc.d
        RC_PATH="/etc/rc.d/rc.local"
        ;;
    *)
        echo "지원하지 않는 OS이므로 rc.local 설정을 건너뜁니다: $OS_ID" | tee -a "$ERROR_LOG"
        exit 1
        ;;
esac

# rc.local 파일이 없다면 기본 틀 생성
if [ ! -f "$RC_PATH" ]; then
    echo "#!/bin/sh -e" > "$RC_PATH"
    echo "" >> "$RC_PATH"
    echo "exit 0" >> "$RC_PATH"
fi

# 'exit 0' 앞에 스크립트 실행 명령 추가 (중복 방지)
if ! grep -q 'Linux_Auto_Script.sh' "$RC_PATH"; then
    sed -i '/^exit 0/i bash /root/LAS/Linux_Auto_Script.sh\n' "$RC_PATH"
fi

# ★★★ 항상 실행 권한 부여 ★★★
chmod +x "$RC_PATH"

# rc.local을 위한 systemd 서비스 파일 생성
RC_SERVICE_FILE="/etc/systemd/system/rc-local.service"
if [ ! -f "$RC_SERVICE_FILE" ]; then
    echo "systemd용 rc-local.service 파일을 생성합니다." | tee -a "$INSTALL_LOG"
    cat <<EOF > "$RC_SERVICE_FILE"
[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=$RC_PATH
[Service]
Type=forking
ExecStart=$RC_PATH start
TimeoutSec=0
StandardOutput=journal+console
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
fi

# 서비스 활성화
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
            # EFI 시스템이면 추가 GRUB 설정
            if [ -f /boot/efi/EFI/"$OS_ID"/grub.cfg ]; then
                grub2-mkconfig -o /boot/efi/EFI/"$OS_ID"/grub.cfg >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            fi
            ;;
    esac

    echo "GRUB 설정 완료. 재부팅 후 적용됩니다." | tee -a "$INSTALL_LOG"
else
    echo "Nouveau 모듈이 이미 비활성화 또는 로드되지 않았습니다. 별도 작업 없이 넘어갑니다." | tee -a "$INSTALL_LOG"
fi


# --- 5. 시스템 설정 (SELinux, Repository) ---
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
        apt update >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        ;;
esac

echo "시스템 설정 완료." | tee -a "$INSTALL_LOG"

# --- 6. 기본 패키지 설치 ---
echo "기본 패키지 설치를 시작합니다." | tee -a "$INSTALL_LOG"
case "$OS_FULL_ID" in
    ubuntu20|ubuntu22|ubuntu24)
        apt -y install build-essential firefox vim nfs-common rdate xauth firefox curl git wget figlet net-tools htop >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        apt -y install smartmontools snapd tmux xfsprogs aptitude lvm2 dstat npm mlocate ntfs-3g >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        apt -y install gnome-tweaks ubuntu-desktop dconf-editor gnome-settings-daemon metacity nautilus gnome-terminal >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        apt -y install ipmitool python3-pip python3-dev >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        ;;
    rocky8|rocky9|almalinux9)
        dnf -y install epel-release >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        dnf -y groupinstall "Server with GUI" "Development Tools" >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        dnf -y install  epel-release >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        dnf -y install ethtool pciutils openssh mlocate nfs-utils xauth firefox nautilus wget bind-utils >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        dnf -y install tcsh tree lshw tmux kernel-headers kernel-devel gcc make gcc-c++ yum-utils >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        dnf -y install cmake dstat perl perl-CPAN perl-core net-tools openssl-devel git-lfs vim  >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        dnf -y install git bash-completion smartmontools ipmitool tar chrony htop >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        ;;
esac
echo "기본 패키지 설치 완료." | tee -a "$INSTALL_LOG"

echo "---"


echo "방화벽 설정을 시작합니다." | tee -a "$INSTALL_LOG"
case "$OS_ID" in
    ubuntu)
        if ufw status | grep -q "Status: inactive"; then
            yes | ufw enable >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        fi

        if ufw status | grep -q "Status: active"; then
            ufw allow 22/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            ufw allow 7777/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG" # 변경될 SSH 포트
            ufw allow 8000/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG" # JupyterHub
            ufw allow 8787/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG" # RStudio Server
            sed -i 's/#Port 22/Port 7777/g' /etc/ssh/sshd_config
            systemctl restart sshd
        else
            echo "ERROR: ufw is not active. Skipping configuration." >> "$ERROR_LOG"
        fi
        ;;

    rocky|almalinux)
        if ! systemctl is-active --quiet firewalld; then
             systemctl enable --now firewalld >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        fi

        if systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-port=22/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            firewall-cmd --permanent --add-port=7777/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG" # 변경될 SSH 포트
            firewall-cmd --permanent --add-port=8000/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG" # JupyterHub
            firewall-cmd --permanent --add-port=8787/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG" # RStudio Server
            firewall-cmd --reload >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            
            sed -i 's/#Port 22/Port 7777/g' /etc/ssh/sshd_config
            sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
            systemctl restart sshd
        else
            echo "ERROR: firewalld is not running. Skipping configuration." >> "$ERROR_LOG"
        fi
        ;;
esac
echo "방화벽 설정 완료." | tee -a "$INSTALL_LOG"


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

    # 루트와 일부 계정의 프롬프트 설정(원하는 계정 추가)
    echo "export PS1='\[\e[1;46;30m\][\u@\h:\W]\\$\[\e[m\] '" >> /root/.bashrc
    if [ -d /home/temp_id ]; then
        echo "export PS1='\[\e[1;47;30m\][\u@\h:\W]\\$\[\e[m\] '" >> /home/temp_id/.bashrc
    fi

    source /etc/profile
    source /root/.bashrc

    echo "" | tee -a "$INSTALL_LOG"
    echo "프로필 설정 완료." | tee -a "$INSTALL_LOG"
else
    echo "" | tee -a "$INSTALL_LOG"
    echo "프로필 설정이 이미 적용되어 있습니다." | tee -a "$INSTALL_LOG"
fi

echo "" | tee -a "$INSTALL_LOG"
sleep 3
echo "" | tee -a "$INSTALL_LOG"

# --- 8. 서버 시간 동기화 ---
echo "서버 시간 동기화 설정을 시작합니다." | tee -a "$INSTALL_LOG"

TIME_LOG="$LOG_DIR/Time_Setting_log.txt"
TIME_ERR="$LOG_DIR/Time_Setting_log_err.txt"

case "$OS_FULL_ID" in
    rocky8|rocky9|rocky10|almalinux8|almalinux9|almalinux10)
        dnf -y install chrony >> "$TIME_LOG" 2>> "$TIME_ERR"
        # 기본 NTP 서버를 국내 kr.pool.ntp.org로 변경
        sed -i 's|^server .*iburst|server kr.pool.ntp.org iburst|' /etc/chrony.conf
        systemctl enable --now chronyd >> "$TIME_LOG" 2>> "$TIME_ERR"
        # 시간대 한국 표준시로 설정
        timedatectl set-timezone Asia/Seoul >> "$TIME_LOG" 2>> "$TIME_ERR"
        chronyc makestep >> "$TIME_LOG" 2>> "$TIME_ERR"
        chronyc sources -v >> "$TIME_LOG" 2>> "$TIME_ERR"
        timedatectl status >> "$TIME_LOG" 2>> "$TIME_ERR"
        date >> "$TIME_LOG"
        hwclock --systohc >> "$TIME_LOG" 2>> "$TIME_ERR"
        ;;
    ubuntu20|ubuntu22|ubuntu24)
        apt -y install chrony >> "$TIME_LOG" 2>> "$TIME_ERR"
        # 기본 NTP 서버를 국내 kr.pool.ntp.org로 변경
        sed -i 's|^pool .* iburst|pool kr.pool.ntp.org iburst|' /etc/chrony/chrony.conf
        systemctl enable --now chrony >> "$TIME_LOG" 2>> "$TIME_ERR"
        # 시간대 한국 표준시로 설정
        timedatectl set-timezone Asia/Seoul >> "$TIME_LOG" 2>> "$TIME_ERR"
        chronyc makestep >> "$TIME_LOG" 2>> "$TIME_ERR"
        chronyc sources -v >> "$TIME_LOG" 2>> "$TIME_ERR"
        timedatectl status >> "$TIME_LOG" 2>> "$TIME_ERR"
        date >> "$TIME_LOG"
        hwclock --systohc >> "$TIME_LOG" 2>> "$TIME_ERR"
        ;;
    *)
        echo "지원하지 않는 OS 버전입니다. 시간 동기화를 건너뜁니다." | tee -a "$TIME_LOG"
        ;;
esac

echo "" | tee -a "$INSTALL_LOG"
echo "서버 시간 동기화 설정 완료." | tee -a "$INSTALL_LOG"
sleep 3
echo "" | tee -a "$INSTALL_LOG"

# --- 9. Python & pip 설치 ---
echo "Python 3 및 pip 설치를 시작합니다." | tee -a "$INSTALL_LOG"

if ! command -v pip3 &>/dev/null; then
    case "$OS_FULL_ID" in
        rocky8|rocky9|rocky10|almalinux8|almalinux9|almalinux10)
            dnf -y install python3 python3-pip >> $LOG_DIR/Python_install_.log 2>> $LOG_DIR/Python_install_log_err.txt
            ;;
        ubuntu20|ubuntu22)
            apt update >> $LOG_DIR/Python_install_.log 2>> $LOG_DIR/Python_install_log_err.txt
            apt -y install python3 python3-pip >> $LOG_DIR/Python_install_.log 2>> $LOG_DIR/Python_install_log_err.txt
            ;;
        *)
            echo "지원하지 않는 OS 또는 버전입니다: $OS_FULL_ID" | tee -a "$INSTALL_LOG"
            ;;
    esac

    python3 -m pip install --upgrade pip >> $LOG_DIR/Python_install_.log 2>> $LOG_DIR/Python_install_log_err.txt
else
    echo "pip3가 이미 설치되어 있습니다." | tee -a "$INSTALL_LOG"
fi

echo "Python 3 및 pip 설치 완료" | tee -a "$INSTALL_LOG"

# --- 10. H/W 사양 체크 ---
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
        lscpu | grep -v "Flags\|NUMA"
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
        echo ""
        echo "Communication Controllers:"
        lspci | grep -i communication
        echo ""
        echo "NIC (dmesg):"
        dmesg | grep NIC
        echo ""

        echo "==================== [ Power Supply Units ] ===================="
        dmidecode --type 39 | grep "System\|Name:\|Capacity"
        echo ""

        echo "==================== [ Disk & Partitions ] ===================="
        blkid
        echo ""

        echo "==================== [ OS Release & Kernel ] ===================="
        uname -a
        echo ""

        echo "############################################################"
        echo "#                  H/W CHECK END                           #"
        echo "############################################################"
    } > $LOG_DIR/HWcheck.txt

    echo "" | tee -a "$INSTALL_LOG"
    echo "=====  H/W Check Complete =====" | tee -a "$INSTALL_LOG"

    # 출력
    echo ""
    echo "===== H/W CHECK RESULT ====="
    cat $LOG_DIR/HWcheck.txt
    echo "============================"
else
    echo "" | tee -a "$INSTALL_LOG"
    echo "H/W check has already been completed." | tee -a "$INSTALL_LOG"

    echo ""
    echo "===== EXISTING H/W CHECK RESULT ====="
    cat $LOG_DIR/HWcheck.txt
    echo "====================================="
fi

echo "" | tee -a "$INSTALL_LOG"
sleep 5
echo "" | tee -a "$INSTALL_LOG"


# --- GPU 체크 및 CPU/GPU 서버 버전 분기 ---
if ! lspci | grep -iq nvidia; then
    echo "" | tee -a "$INSTALL_LOG"
    echo "Complete basic setup" | tee -a "$INSTALL_LOG"

    case "$OS_FULL_ID" in
        rocky8|rocky9|almalinux9)
            if ! dmidecode | grep -iq ipmi; then
                echo "" | tee -a "$INSTALL_LOG"
                echo "End of CPU version LAS" | tee -a "$INSTALL_LOG"
                if ! grep -q "bash /root/LAS/Check_List.sh" /etc/rc.d/rc.local; then
                    sed -i '13a bash /root/LAS/Check_List.sh' /etc/rc.d/rc.local
                fi
                systemctl set-default graphical.target >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                reboot
            else
                echo "" | tee -a "$INSTALL_LOG"
                echo "The server version continues." | tee -a "$INSTALL_LOG"
                if [ ! -f $LOG_DIR/nvidia.txt ]; then
                    touch $LOG_DIR/nvidia.txt
                    reboot
                fi
            fi
            ;;

        ubuntu20|ubuntu22|ubuntu24)
            if ! dmidecode | grep -iq ipmi; then
                echo "" | tee -a "$INSTALL_LOG"
                echo "End of CPU version LAS" | tee -a "$INSTALL_LOG"
                if ! grep -q "bash /root/LAS/Check_List.sh" /etc/rc.local; then
                    sed -i '1a bash /root/LAS/Check_List.sh' /etc/rc.local
                fi
                systemctl set-default graphical.target >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
                reboot
            else
                echo "" | tee -a "$INSTALL_LOG"
                echo "The server version continues." | tee -a "$INSTALL_LOG"
                if [ ! -f $LOG_DIR/nvidia.txt ]; then
                    touch $LOG_DIR/nvidia.txt
                    reboot
                fi
            fi
            ;;

        *)
            ;;
    esac
else
    echo "" | tee -a "$INSTALL_LOG"
    echo "GPU Settings Start." | tee -a "$INSTALL_LOG"
    if [ ! -f $LOG_DIR/nvidia.txt ]; then
        touch $LOG_DIR/nvidia.txt
        reboot
    fi
fi

sleep 3

if grep -q "No" $LOG_DIR/cudaversion.txt; then
    OS="Skip this server as it has no GPU."
else
    echo ""
fi

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_VERSION_MAJOR=$(echo "$VERSION_ID" | cut -d. -f1)
    OS_FULL_ID="${OS_ID}${OS_VERSION_MAJOR}"
else
    echo "OS 정보를 확인할 수 없습니다. /etc/os-release 없음" | tee -a $LOG_DIR/install_.log
    exit 1
fi

# 11. CUDA, CUDNN Repo install

# 기본 부팅 타겟을 multi-user (텍스트 모드)로 설정

systemctl set-default multi-user.target | tee -a "$INSTALL_LOG"

ls /usr/local/ | grep cuda &> /dev/null
if [ $? != 0 ]; then
  case $OS_FULL_ID in
    rocky8|almalinux8)
      dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
      wget https://developer.download.nvidia.com/compute/machine-learning/repos/rhel8/x86_64/nvidia-machine-learning-repo-rhel8-1.0.0-1.x86_64.rpm >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
      dnf -y install nvidia-machine-learning-repo-rhel8-1.0.0-1.x86_64.rpm >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
      dnf -y install libXi-devel mesa-libGLU-devel libXmu-devel libX11-devel freeglut-devel libXm* openmotif* >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
      ;;
    rocky9|almalinux9)
      dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
      dnf -y install libXi-devel mesa-libGLU-devel libXmu-devel libX11-devel freeglut-devel libXm* openmotif* >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
      ;;
    rocky10|almalinux10)
      dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel10/x86_64/cuda-rhel10.repo >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
      dnf -y install libXi-devel mesa-libGLU-devel libXmu-devel libX11-devel freeglut-devel libXm* openmotif* >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
      ;;
    ubuntu20|ubuntu22|ubuntu24)
      apt -y install sudo gnupg >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt           
      apt-key adv --fetch-keys "https://developer.download.nvidia.com/compute/cuda/repos/"${OS_FULL_ID}04"/x86_64/3bf863cc.pub" >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
      sh -c 'echo "deb https://developer.download.nvidia.com/compute/cuda/repos/'${OS_FULL_ID}04'/x86_64 /" > /etc/apt/sources.list.d/nvidia-cuda.list' >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
      apt update >> $LOG_DIR/GPU_repo_log.txt 2>> $LOG_DIR/GPU_repo_log_err.txt
      ;;
    *)
      echo "CUDA,CUDNN repo not installed for this OS: $OS_FULL_ID" | tee -a $LOG_DIR/install_.log
      ;;
  esac
else
  echo "The CUDA REPO has already been installed." | tee -a $LOG_DIR/install_.log
fi

echo "" | tee -a $LOG_DIR/install_.log
sleep 3
echo "" | tee -a $LOG_DIR/install_.log

# 12. CUDA install / PATH setting
ls /usr/local/ | grep cuda >> $LOG_DIR/install_.log 2>> $LOG_DIR/log_err.txt
if [ $? != 0 ]; then
  CUDAV=$(cat $LOG_DIR/cudaversion.txt)
  if [ "$CUDAV" = "No-GPU" ]; then
    echo "No-GPU: not install cuda" >> $LOG_DIR/install_.log 2>> $LOG_DIR/log_err.txt
  else
    CUDAV_U="${CUDAV/-/.}"
    case $OS_FULL_ID in
      rocky8|almalinux8|rocky9|almalinux9|rocky10|almalinux10)
        echo "CUDA $CUDAV 설치 시작" | tee -a $LOG_DIR/install_.log
        if ! grep -q "ADD Cuda" /etc/profile; then
          echo "" >> /etc/profile
          echo "### ADD Cuda $CUDAV_U PATH" >> /etc/profile
          echo "export PATH=/usr/local/cuda-$CUDAV_U/bin:/usr/local/cuda-$CUDAV_U/include:\$PATH" >> /etc/profile
          echo "export LD_LIBRARY_PATH=/usr/local/cuda-$CUDAV_U/lib64:/usr/local/cuda/extras/CUPTI/:\$LD_LIBRARY_PATH" >> /etc/profile
          echo "export CUDA_HOME=/usr/local/cuda-$CUDAV_U" >> /etc/profile
          echo "export CUDA_INC_DIR=/usr/local/cuda-$CUDAV_U/include" >> /etc/profile
        fi
        sleep 1
        dnf -y install cuda-$CUDAV >> $LOG_DIR/cuda_cudnn_install_.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
        sleep 1
        nvidia-smi -pm 1 >> $LOG_DIR/cuda_cudnn_install_.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
        systemctl enable nvidia-persistenced >> $LOG_DIR/cuda_cudnn_install_.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
        source /etc/profile
        source /root/.bashrc
        echo "CUDA $CUDAV 설치 완료" | tee -a $LOG_DIR/install_.log
      ;;
      ubuntu20|ubuntu22|ubuntu24)
        echo "CUDA $CUDAV 설치 시작" | tee -a $LOG_DIR/install_.log
        if ! grep -q "ADD Cuda" /etc/profile; then
          echo "" >> /etc/profile
          echo "### ADD Cuda $CUDAV_U PATH" >> /etc/profile
          echo "export PATH=/usr/local/cuda-$CUDAV_U/bin:/usr/local/cuda-$CUDAV_U/include:\$PATH" >> /etc/profile
          echo "export LD_LIBRARY_PATH=/usr/local/cuda-$CUDAV_U/lib64:/usr/local/cuda/extras/CUPTI/:\$LD_LIBRARY_PATH" >> /etc/profile
          echo "export CUDA_HOME=/usr/local/cuda-$CUDAV_U" >> /etc/profile
          echo "export CUDA_INC_DIR=/usr/local/cuda-$CUDAV_U/include" >> /etc/profile
        fi
        sleep 1
        apt -y install cuda-toolkit-$CUDAV >> $LOG_DIR/cuda_cudnn_install_.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
        sleep 1
        ubuntu-drivers autoinstall >> $LOG_DIR/cuda_cudnn_install_.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
        nvidia-smi -pm 1 >> $LOG_DIR/cuda_cudnn_install_.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
        systemctl enable nvidia-persistenced >> $LOG_DIR/cuda_cudnn_install_.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
        source /etc/profile
        source /root/.bashrc
        echo "CUDA $CUDAV 설치 완료" | tee -a $LOG_DIR/install_.log
      ;;
      *)
        echo "CUDA not install: $OS_FULL_ID" | tee -a $LOG_DIR/install_.log
      ;;
    esac
  fi
else
  echo "The CUDA has already been installed." | tee -a $LOG_DIR/install_.log
fi

echo "" | tee -a $LOG_DIR/install_.log
sleep 3
echo "" | tee -a $LOG_DIR/install_.log

# --- 13. CUDNN 9 install ---
echo "CUDNN 9 설치를 시작합니다." | tee -a "$INSTALL_LOG"

CUDAV=$(cat $LOG_DIR/cudaversion.txt 2>/dev/null)
if [ -z "$CUDAV" ] || [ "$CUDAV" = "No-GPU" ]; then
    echo "No GPU 또는 CUDA 버전 미설정 상태입니다. CUDNN 설치를 건너뜁니다." | tee -a "$INSTALL_LOG"
else
    if [[ "$CUDAV" == *"-"* ]]; then
        CUDA_MAJOR=${CUDAV%%-*}
    else
        CUDA_MAJOR=$CUDAV
    fi
    
    case "$OS_FULL_ID" in
        rocky8|rocky9|almalinux9|rocky10|almalinux10)
            echo " CUDNN 설치 시작" | tee -a "$INSTALL_LOG"
            dnf -y install \
                cudnn9-cuda-${CUDA_MAJOR} \
                libcudnn9-devel-cuda-${CUDA_MAJOR} \
                libcudnn9-headers-cuda-${CUDA_MAJOR} \
                libcudnn9-samples \
                >> $LOG_DIR/cuda_cudnn_install_.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
            echo "CUDNN 설치 완료" | tee -a "$INSTALL_LOG"
            ;;

        ubuntu20|ubuntu22|ubuntu24)
            echo " CUDNN 9 설치 시작" | tee -a "$INSTALL_LOG"
            apt -y install \
                libcudnn9-cuda-${CUDA_MAJOR} \
                libcudnn9-dev-cuda-${CUDA_MAJOR} \
                libcudnn9-headers-cuda-${CUDA_MAJOR} \
                libcudnn9-samples \
                >> $LOG_DIR/cuda_cudnn_install_.log 2>> $LOG_DIR/cuda_cudnn_install_log_err.txt
            echo "CUDNN 설치 완료" | tee -a "$INSTALL_LOG"
            ;;

        *)
            echo "지원하지 않는 OS 또는 버전입니다: $OS_FULL_ID" | tee -a "$INSTALL_LOG"
            ;;
    esac
fi



# ---14. LSA install ---

echo "===== LSA 설치 시작 ====="

mkdir -p /root/LSA
cd /root/LSA

wget https://docs.broadcom.com/docs-and-downloads/008.012.007.000_MR7.32_LSA_Linux.zip

unzip -o 008.012.007.000_MR7.32_LSA_Linux.zip
cd webgui_rel
unzip -o LSA_Linux.zip
ls -l

cd gcc_8.3.x
case "$OS_ID" in
    rocky|almalinux)
        if [ -f install.sh ]; then
            yes | ./install.sh -s
            echo "Rocky/AlmaLinux: install.sh 실행 완료" | tee -a "$INSTALL_LOG"
        else
            echo "[WARN] install.sh 파일이 없습니다." | tee -a "$INSTALL_LOG"
        fi
        ;;
    ubuntu)
        if [ -f install_deb.sh ]; then
            yes | ./install_deb.sh -s
            echo "Ubuntu: install_deb.sh 실행 완료" | tee -a "$INSTALL_LOG"
        else
            echo "[WARN] install_deb.sh 파일이 없습니다." | tee -a "$INSTALL_LOG"
        fi
        ;;
    *)
        echo "[WARN] 지원하지 않는 OS: $OS_ID" | tee -a "$INSTALL_LOG"
        ;;
esac

cd
echo "=== LSA 설치 스크립트 완료 ==="

mkdir -p /etc/lsisash
mv /etc/init.d/LsiSASH /etc/lsisash/LsiSASH
chmod +x /etc/lsisash/LsiSASH



case "$OS_FULL_ID" in
    rocky8|rocky9|rocky10|almalinux8|almalinux9|almalinux10)
        firewall-cmd --zone=public --add-service=http --permanent
        firewall-cmd --zone=public --add-port=2463/tcp --permanent
        firewall-cmd --reload
        ;;
    ubuntu20|ubuntu22|ubuntu24)
        ufw allow http
        ufw allow 2463/tcp
        ufw reload
        ;;
esac

SYSTEMD_FILE="/etc/systemd/system/lsisash.service"
if [ ! -f "$SYSTEMD_FILE" ]; then
    cat <<EOF > "$SYSTEMD_FILE"
[Unit]
Description=Start LsiSASH service at boot
After=network.target

[Service]
Type=simple
User=root
ExecStart=/etc/lsisash/LsiSASH start
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable lsisash.service
    systemctl start lsisash.service
    systemctl status lsisash.service
    echo "lsisash.service 서비스 등록 및 시작 완료"
else
    echo "lsisash.service 서비스가 이미 존재합니다."
fi

cd
rm -rf LSA
echo "===== LSA 설치 및 설정 완료 ====="


# --- 19. Dell OMSA install ---
echo "OMSA 설치를 시작합니다." | tee -a "$INSTALL_LOG"

if ! systemctl is-active --quiet dsm_om_connsvc; then
    case "$OS_FULL_ID" in
        rocky8|almalinux8|rocky9|almalinux9|rocky10|almalinux10)
            echo "RHEL 계열 OMSA 설치" | tee -a "$INSTALL_LOG"
            firewall-cmd --permanent --add-port=1311/tcp
            firewall-cmd --reload

            wget http://linux.dell.com/repo/hardware/dsu/bootstrap.cgi -O ./dellomsainstall.sh
            sed -i -e "s/enabled=1/enabled=0/g" ./dellomsainstall.sh
            yes | bash ./dellomsainstall.sh

            dnf -y install --enablerepo=dell-system-update_dependent srvadmin-all openssl-devel

            systemctl daemon-reload
            systemctl enable dsm_om_connsvc
            systemctl start dsm_om_connsvc
            ;;
        ubuntu20)
            echo "Ubuntu 계열 OMSA 설치" | tee -a "$INSTALL_LOG"
            ufw allow 1311/tcp

            echo 'deb http://linux.dell.com/repo/community/openmanage/10300/focal focal main' \
                > /etc/apt/sources.list.d/linux.dell.com.sources.list
            wget http://linux.dell.com/repo/pgp_pubkeys/0x1285491434D8786F.asc
            apt-key add 0x1285491434D8786F.asc
            apt -y update
            pip install --upgrade pyOpenSSL cryptography
            apt -y install srvadmin-all

            #if [ ! -f /usr/lib/x86_64-linux-gnu/libssl.so ]; then
            #    ln -s /usr/lib/x86_64-linux-gnu/libssl.so.1.1 /usr/lib/x86_64-linux-gnu/libssl.so
            #fi

            systemctl daemon-reload
            systemctl enable dsm_sa_datamgrd.service
            systemctl enable dsm_om_connsvc
            systemctl start dsm_sa_datamgrd.service
            systemctl start dsm_om_connsvc
            ;;
        ubuntu22|ubuntu24)
            echo "Ubuntu 계열 OMSA 설치" | tee -a "$INSTALL_LOG"
            ufw allow 1311/tcp

            echo 'deb http://linux.dell.com/repo/community/openmanage/10300/focal focal main' \
                > /etc/apt/sources.list.d/linux.dell.com.sources.list
            wget http://linux.dell.com/repo/pgp_pubkeys/0x1285491434D8786F.asc
            apt-key add 0x1285491434D8786F.asc
            apt -y update
            wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
            dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb
            apt -y install srvadmin-all

            #if [ ! -f /usr/lib/x86_64-linux-gnu/libssl.so ]; then
            #    ln -s /usr/lib/x86_64-linux-gnu/libssl.so.1.1 /usr/lib/x86_64-linux-gnu/libssl.so
            #fi

            systemctl daemon-reload
            systemctl enable dsm_sa_datamgrd.service
            systemctl enable dsm_om_connsvc
            systemctl start dsm_sa_datamgrd.service
            systemctl start dsm_om_connsvc
            ;;
    esac
else
    echo "OMSA가 이미 설치되어 있습니다." | tee -a "$INSTALL_LOG"
fi

echo "" | tee -a $LOG_DIR/install_.log
sleep 3
echo "" | tee -a $LOG_DIR/install_.log

echo "" | tee -a $LOG_DIR/install_.log
echo "LAS install complete" | tee -a $LOG_DIR/install_.log

echo "모든 설치 완료. 최종 정리 작업을 수행합니다." | tee -a "$INSTALL_LOG"

# rc.local에서 메인 스크립트 자동 실행 항목 제거
case "$OS_ID" in
    ubuntu) RC_PATH="/etc/rc.local" ;;
    rocky|almalinux) RC_PATH="/etc/rc.d/rc.local" ;;
esac
if [ -n "$RC_PATH" ] && [ -f "$RC_PATH" ]; then
    sed -i "\|bash $SCRIPT_PATH|d" "$RC_PATH" # SCRIPT_PATH는 메인 스크립트 경로 변수
    echo "$RC_PATH에서 메인 스크립트 자동 실행 항목을 제거했습니다." | tee -a "$INSTALL_LOG"
    
    #  Check_List.sh를 다음 부팅 시 한 번만 실행하도록 등록 ★★★
    if [ -f /root/LAS/Check_List.sh ]; then
        echo "bash /root/LAS/Check_List.sh" >> "$RC_PATH"
        chmod +x /root/LAS/Check_List.sh
        echo "다음 부팅 시 Check_List.sh를 실행하도록 등록했습니다." | tee -a "$INSTALL_LOG"
    fi
fi

#  최종 부팅 타겟 설정
systemctl set-default multi-user.target | tee -a "$INSTALL_LOG"

echo "모든 작업이 최종 완료되었습니다. 시스템을 재부팅하여 마지막 점검을 수행합니다." | tee -a "$INSTALL_LOG"
reboot

