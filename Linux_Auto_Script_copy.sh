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
    echo "OS 정보를 확인할 수 없습니다. /etc/os-release 파일이 없습니다." | tee -a /root/install_log.txt
    exit 1
fi

LOG_DIR="/root/LAS_LOGS"
mkdir -p "$LOG_DIR"
INSTALL_LOG="$LOG_DIR/install.log"
ERROR_LOG="$LOG_DIR/error.log"

echo "스크립트 실행 로그는 $LOG_DIR 에 저장됩니다."

# --- 2. CUDA 버전 선택 ---
if [ ! -f /root/cudaversion.txt ]; then
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
                echo "$CUDAV" > /root/cudaversion.txt
                break
            else
                echo "잘못된 선택입니다. 다시 시도하세요."
            fi
        done
    else
        echo "지원되는 OS가 아니므로 CUDA 버전을 선택할 수 없습니다." | tee -a "$INSTALL_LOG"
        echo "No-GPU" > /root/cudaversion.txt
    fi
    echo "CUDA 버전 선택 완료." | tee -a "$INSTALL_LOG"
else
    echo "CUDA 버전이 이미 선택되었습니다." | tee -a "$INSTALL_LOG"
fi

# --- 3. 부팅 스크립트(rc.local) 설정 ---
if [ ! -f /etc/rc.local ]; then
    echo "rc.local 설정을 시작합니다." | tee -a "$INSTALL_LOG"
    case "$OS_ID" in
        ubuntu)
            RC_PATH="/etc/rc.local"
            ;;
        rocky|almalinux)
            RC_PATH="/etc/rc.d/rc.local"
            ;;
    esac

    echo -e '#!/bin/sh -e\n' > "$RC_PATH"
    # 아래 라인에 부팅 시 실행할 스크립트를 추가합니다.
    echo 'bash /root/LAS/Linux_Auto_Script.sh' >> "$RC_PATH"
    echo -e '\nexit 0' >> "$RC_PATH"

    chmod +x "$RC_PATH"
    systemctl enable rc-local.service >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
    systemctl start rc-local.service >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
    echo "rc.local 설정 완료." | tee -a "$INSTALL_LOG"
else
    echo "rc.local 파일이 이미 존재합니다." | tee -a "$INSTALL_LOG"
fi


# --- 4. Nouveau 비활성화 및 GRUB 설정 ---
if lsmod | grep -q "^nouveau"; then
    echo "Nouveau 드라이버 비활성화 및 GRUB 설정을 시작합니다." | tee -a "$INSTALL_LOG"
    
    # nouveau 모듈 블랙리스트 설정
    echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nouveau.conf
    echo "options nouveau modeset=0" >> /etc/modprobe.d/blacklist-nouveau.conf

    # OS별 initramfs 및 GRUB 설정 적용
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
            sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
        fi
        ;;
    ubuntu)
        echo "Ubuntu APT 저장소를 mirror.kakao.com으로 변경합니다." | tee -a "$INSTALL_LOG"
        sed -i 's/kr.archive.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list
        sed -i 's/security.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list
        apt-get update >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        ;;
esac
echo "시스템 설정 완료." | tee -a "$INSTALL_LOG"


# --- 6. 기본 패키지 설치 ---
echo "기본 패키지 설치를 시작합니다." | tee -a "$INSTALL_LOG"
case "$OS_FULL_ID" in
    ubuntu22|ubuntu24)
        apt-get -y install build-essential vim nfs-common rdate curl git wget figlet net-tools htop dstat \
        gnome-tweaks ubuntu-desktop-minimal dconf-editor smartmontools \
        python3-pip python3-dev >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        ;;
    rocky8|rocky9|almalinux9)
        dnf -y install epel-release >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        dnf -y groupinstall "Server with GUI" "Development Tools" >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        dnf -y install  epel-release >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        dnf -y install \
        ethtool pciutils openssh mlocate nfs-utils xauth firefox nautilus wget bind-utils \
        tcsh tree lshw tmux kernel-headers kernel-devel gcc make gcc-c++ yum-utils \
        cmake dstat perl perl-CPAN perl-core net-tools openssl-devel git-lfs vim  \
        git bash-completion smartmontools ipmitool tar chrony htop \
        >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        ;;
esac
echo "기본 패키지 설치 완료." | tee -a "$INSTALL_LOG"

echo "---"


echo "방화벽 설정을 시작합니다." | tee -a "$INSTALL_LOG"
case "$OS_ID" in
    ubuntu)
        if ! ufw status | grep -q "active"; then
            ufw allow 22/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            ufw allow 7777/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG" # 변경될 SSH 포트
            ufw allow 8000/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG" # JupyterHub
            ufw allow 8787/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG" # RStudio Server
            yes | ufw enable >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            sed -i 's/#Port 22/Port 7777/g' /etc/ssh/sshd_config
            systemctl restart sshd
        fi
        ;;
    rocky|almalinux)
        if ! firewall-cmd --state | grep -q "running"; then
             systemctl enable --now firewalld
        fi
        firewall-cmd --permanent --add-port=7777/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG" # 변경될 SSH 포트
        firewall-cmd --permanent --add-port=8000/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG" # JupyterHub
        firewall-cmd --permanent --add-port=8787/tcp >> "$INSTALL_LOG" 2>> "$ERROR_LOG" # RStudio Server
        firewall-cmd --reload >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        sed -i 's/#Port 22/Port 7777/g' /etc/ssh/sshd_config
        sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
        systemctl restart sshd
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
    if [ -d /home/kds ]; then
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
    rocky8)
        dnf install -y chrony >> "$TIME_LOG" 2>> "$TIME_ERR"
        sed -i 's/pool 2.pool.ntp.org iburst/pool kr.pool.ntp.org iburst/' /etc/chrony.conf
        systemctl enable chronyd >> "$TIME_LOG" 2>> "$TIME_ERR"
        systemctl start chronyd >> "$TIME_LOG" 2>> "$TIME_ERR"
        chronyc sources >> "$TIME_LOG" 2>> "$TIME_ERR"
        timedatectl >> "$TIME_LOG" 2>> "$TIME_ERR"
        clock --systohc >> "$TIME_LOG" 2>> "$TIME_ERR"
        date >> "$TIME_LOG" 2>> "$TIME_ERR"
        hwclock >> "$TIME_LOG" 2>> "$TIME_ERR"
        ;;
    ubuntu22|ubuntu24|rocky9|almalinux9)
        echo "OS 내장 시간동기화 서비스 사용 (systemd-timesyncd 또는 chrony)" | tee -a "$TIME_LOG"
        timedatectl set-ntp true >> "$TIME_LOG" 2>> "$TIME_ERR"
        timedatectl >> "$TIME_LOG" 2>> "$TIME_ERR"
        date >> "$TIME_LOG" 2>> "$TIME_ERR"
        hwclock --systohc >> "$TIME_LOG" 2>> "$TIME_ERR"
        ;;
    *)
        echo "Start time setting (rdate/hwclock)" | tee -a "$TIME_LOG"
        rdate -s time.bora.net >> "$TIME_LOG" 2>> "$TIME_ERR"
        hwclock --systohc >> "$TIME_LOG" 2>> "$TIME_ERR"
        date >> "$TIME_LOG" 2>> "$TIME_ERR"
        hwclock >> "$TIME_LOG" 2>> "$TIME_ERR"
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
            dnf -y install python3 python3-pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
            ;;
        ubuntu2004|ubuntu2204|ubuntu2404)
            apt-get update >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
            apt-get -y install python3 python3-pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
            ;;
        *)
            echo "지원하지 않는 OS 또는 버전입니다: $OS_FULL_ID" | tee -a "$INSTALL_LOG"
            ;;
    esac

    python3 -m pip install --upgrade pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
else
    echo "pip3가 이미 설치되어 있습니다." | tee -a "$INSTALL_LOG"
fi

echo "Python 3 및 pip 설치 완료" | tee -a "$INSTALL_LOG"

# --- 10. H/W 사양 체크 ---
if [ ! -f /root/HWcheck.txt ]; then
    echo "===== H/W Check Start =====" | tee -a "$INSTALL_LOG"
    touch /root/HWcheck.txt

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
    } > /root/HWcheck.txt

    echo "" | tee -a "$INSTALL_LOG"
    echo "=====  H/W Check Complete =====" | tee -a "$INSTALL_LOG"

    # 출력
    echo ""
    echo "===== H/W CHECK RESULT ====="
    cat /root/HWcheck.txt
    echo "============================"
else
    echo "" | tee -a "$INSTALL_LOG"
    echo "H/W check has already been completed." | tee -a "$INSTALL_LOG"

    echo ""
    echo "===== EXISTING H/W CHECK RESULT ====="
    cat /root/HWcheck.txt
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
                if [ ! -f /root/nvidia.txt ]; then
                    touch /root/nvidia.txt
                    reboot
                fi
            fi
            ;;

        ubuntu2004|ubuntu2204|ubuntu22|ubuntu24)
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
                if [ ! -f /root/nvidia.txt ]; then
                    touch /root/nvidia.txt
                    reboot
                fi
            fi
            ;;

        *)
            # 기타 OS는 별도 처리 없음
            ;;
    esac
else
    echo "" | tee -a "$INSTALL_LOG"
    echo "GPU Settings Start." | tee -a "$INSTALL_LOG"
    if [ ! -f /root/nvidia.txt ]; then
        touch /root/nvidia.txt
        reboot
    fi
fi

sleep 3

# --- GPU 없으면 Skip 표시 ---
if grep -q "No" /root/cudaversion.txt; then
    OS="Skip this server as it has no GPU."
else
    echo ""
fi


# 11. CUDA, CUDNN Repo 설치 (필요 OS만 지원)
ls /usr/local/ | grep cuda &> /dev/null
if [ $? != 0 ]; then
  case $OS_FULL_ID in
    rocky8|almalinux8)
      dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      wget https://developer.download.nvidia.com/compute/machine-learning/repos/rhel8/x86_64/nvidia-machine-learning-repo-rhel8-1.0.0-1.x86_64.rpm >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      dnf -y install nvidia-machine-learning-repo-rhel8-1.0.0-1.x86_64.rpm >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      dnf -y install libXi-devel mesa-libGLU-devel libXmu-devel libX11-devel freeglut-devel libXm* openmotif* >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      ;;
    rocky9|almalinux9)
      dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      dnf -y install libXi-devel mesa-libGLU-devel libXmu-devel libX11-devel freeglut-devel libXm* openmotif* >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      ;;
    rocky10|almalinux10)
      dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel10/x86_64/cuda-rhel10.repo >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      dnf -y install libXi-devel mesa-libGLU-devel libXmu-devel libX11-devel freeglut-devel libXm* openmotif* >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      ;;
    ubuntu2004|ubuntu2204|ubuntu2404)
      apt-get -y install sudo gnupg >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${OS_VERSION_MAJOR}04/x86_64/3bf863cc.pub -O /usr/share/keyrings/cuda-archive-keyring.gpg >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      echo "deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${OS_VERSION_MAJOR}04/x86_64/ /" > /etc/apt/sources.list.d/nvidia-cuda.list
      apt-get update >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      ;;
    *)
      echo "CUDA,CUDNN repo not installed for this OS: $OS_FULL_ID" | tee -a /root/install_log.txt
      ;;
  esac
else
  echo "The CUDA REPO has already been installed." | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

# 12. CUDA 설치 및 PATH 설정
ls /usr/local/ | grep cuda >> /root/install_log.txt 2>> /root/log_err.txt
if [ $? != 0 ]; then
  CUDAV=$(cat /root/cudaversion.txt)
  if [ "$CUDAV" = "No-GPU" ]; then
    echo "No-GPU: not install cuda" >> /root/install_log.txt 2>> /root/log_err.txt
  else
    CUDAV_U="${CUDAV/-/.}"
    case $OS_FULL_ID in
      rocky8|almalinux8|rocky9|almalinux9|rocky10|almalinux10)
        echo "CUDA $CUDAV 설치 시작" | tee -a /root/install_log.txt
        if ! grep -q "ADD Cuda" /etc/profile; then
          echo "" >> /etc/profile
          echo "### ADD Cuda $CUDAV_U PATH" >> /etc/profile
          echo "export PATH=/usr/local/cuda-$CUDAV_U/bin:/usr/local/cuda-$CUDAV_U/include:\$PATH" >> /etc/profile
          echo "export LD_LIBRARY_PATH=/usr/local/cuda-$CUDAV_U/lib64:/usr/local/cuda/extras/CUPTI/:\$LD_LIBRARY_PATH" >> /etc/profile
          echo "export CUDA_HOME=/usr/local/cuda-$CUDAV_U" >> /etc/profile
          echo "export CUDA_INC_DIR=/usr/local/cuda-$CUDAV_U/include" >> /etc/profile
        fi
        sleep 1
        dnf -y install cuda-$CUDAV >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
        sleep 1
        nvidia-smi -pm 1 >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
        systemctl enable nvidia-persistenced >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
        source /etc/profile
        source /root/.bashrc
        echo "CUDA $CUDAV 설치 완료" | tee -a /root/install_log.txt
      ;;
      ubuntu2004|ubuntu2204|ubuntu2404)
        echo "CUDA $CUDAV 설치 시작" | tee -a /root/install_log.txt
        if ! grep -q "ADD Cuda" /etc/profile; then
          echo "" >> /etc/profile
          echo "### ADD Cuda $CUDAV_U PATH" >> /etc/profile
          echo "export PATH=/usr/local/cuda-$CUDAV_U/bin:/usr/local/cuda-$CUDAV_U/include:\$PATH" >> /etc/profile
          echo "export LD_LIBRARY_PATH=/usr/local/cuda-$CUDAV_U/lib64:/usr/local/cuda/extras/CUPTI/:\$LD_LIBRARY_PATH" >> /etc/profile
          echo "export CUDA_HOME=/usr/local/cuda-$CUDAV_U" >> /etc/profile
          echo "export CUDA_INC_DIR=/usr/local/cuda-$CUDAV_U/include" >> /etc/profile
        fi
        sleep 1
        apt-get -y install cuda-$CUDAV >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
        sleep 1
        nvidia-smi -pm 1 >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
        systemctl enable nvidia-persistenced >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
        source /etc/profile
        source /root/.bashrc
        echo "CUDA $CUDAV 설치 완료" | tee -a /root/install_log.txt
      ;;
      *)
        echo "CUDA not install: $OS_FULL_ID" | tee -a /root/install_log.txt
      ;;
    esac
  fi
else
  echo "The CUDA has already been installed." | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

# --- 13. CUDNN 9 설치 ---
echo "CUDNN 9 설치를 시작합니다." | tee -a "$INSTALL_LOG"

CUDAV=$(cat /root/cudaversion.txt 2>/dev/null)
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
            echo " CUDNN 설치 (CUDA $CUDAV_DOTTED) 시작" | tee -a "$INSTALL_LOG"
            dnf -y install \
                cudnn9-cuda-${CUDA_MAJOR} \
                libcudnn9-devel-cuda-${CUDA_MAJOR} \
                libcudnn9-headers-cuda-${CUDA_MAJOR} \
                libcudnn9-samples \
                >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
            echo "CUDNN 설치 완료" | tee -a "$INSTALL_LOG"
            ;;

        ubuntu2004|ubuntu2204|ubuntu2404)
            echo " CUDNN 9 설치 (CUDA $CUDAV_DOTTED) 시작" | tee -a "$INSTALL_LOG"
            apt-get -y install \
                libcudnn9-cuda-${CUDA_MAJOR} \
                libcudnn9-dev-cuda-${CUDA_MAJOR} \
                libcudnn9-headers-cuda-${CUDA_MAJOR} \
                libcudnn9-samples \
                >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
            echo "CUDNN 설치 완료" | tee -a "$INSTALL_LOG"
            ;;

        *)
            echo "지원하지 않는 OS 또는 버전입니다: $OS_FULL_ID" | tee -a "$INSTALL_LOG"
            ;;
    esac
fi

# --- 16. R 및 RStudio Server 설치 ---
echo "R 및 RStudio Server 설치를 시작합니다." | tee -a "$INSTALL_LOG"

case "$OS_FULL_ID" in
    rocky8|almalinux8)
        dnf config-manager --set-enabled powertools >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        dnf -y install R libcurl-devel libxml2-devel >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        wget -O /tmp/rstudio-server-latest.rpm \
            https://download2.rstudio.org/server/rhel8/x86_64/rstudio-server-rhel-2025.05.1-513-x86_64.rpm \
            >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        dnf -y install /tmp/rstudio-server-latest.rpm >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        rm -f /tmp/rstudio-server-latest.rpm
        ;;
    rocky9|almalinux9|rocky10|almalinux10)
        dnf config-manager --set-enabled crb >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        dnf -y install R libcurl-devel libxml2-devel >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        wget -O /tmp/rstudio-server-latest.rpm \
        https://download2.rstudio.org/server/rhel9/x86_64/rstudio-server-rhel-2025.05.1-513-x86_64.rpm \
            >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        dnf -y install /tmp/rstudio-server-latest.rpm >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        rm -f /tmp/rstudio-server-latest.rpm
        ;;
    ubuntu2004)
        apt-get update >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        apt-get -y install r-base libcurl4-openssl-dev libxml2-dev >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        wget -O /tmp/rstudio-server-latest.deb \
            wget https://download2.rstudio.org/server/focal/amd64/rstudio-server-2025.05.1-513-amd64.deb \
            >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        apt-get -y install /tmp/rstudio-server-latest.deb >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        rm -f /tmp/rstudio-server-latest.deb
        ;;
    ubuntu2204)
        apt-get update >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        apt-get -y install r-base libcurl4-openssl-dev libxml2-dev >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        wget -O /tmp/rstudio-server-latest.deb \
            https://download2.rstudio.org/server/jammy/amd64/rstudio-server-2025.05.1-513-amd64.deb \
            >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        apt-get -y install /tmp/rstudio-server-latest.deb >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        rm -f /tmp/rstudio-server-latest.deb
        ;;
    ubuntu2404)
        apt-get update >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        apt-get -y install r-base libcurl4-openssl-dev libxml2-dev >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        wget -O /tmp/rstudio-server-latest.deb \
            https://download2.rstudio.org/server/jammy/amd64/rstudio-server-2025.05.1-513-amd64.deb \
            >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        apt-get -y install /tmp/rstudio-server-latest.deb >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        rm -f /tmp/rstudio-server-latest.deb
        ;;
    *)
        echo "지원하지 않는 OS 또는 버전입니다: $OS_FULL_ID" | tee -a "$INSTALL_LOG"
        ;;
esac

echo "R 및 RStudio Server 설치 완료" | tee -a "$INSTALL_LOG"


# --- 17. JupyterHub & JupyterLab 설치 및 설정 ---
echo "JupyterHub, JupyterLab 설치를 시작합니다." | tee -a "$INSTALL_LOG"

rpm -e --nodeps python3-requests >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
python3 -m pip install --upgrade pip setuptools wheel >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
python3 -m pip install jupyterhub jupyterlab notebook >> "$INSTALL_LOG" 2>> "$ERROR_LOG"

# Node.js 16 설치
case "$OS_FULL_ID" in
    ubuntu2004|ubuntu2204|ubuntu2404)
        curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        apt-get -y install nodejs >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        ;;
    rocky8|almalinux8|rocky9|almalinux9|rocky10|almalinux10)
        curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        sed -i '/failover/d' /etc/yum.repos.d/nodesource-nodejs.repo
        dnf -y install nodejs >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        ;;
esac

npm install -g configurable-http-proxy >> "$INSTALL_LOG" 2>> "$ERROR_LOG"

# JupyterHub 설정
JUPYTER_CONFIG_DIR="/etc/jupyterhub"
JUPYTER_CONFIG_FILE="$JUPYTER_CONFIG_DIR/jupyterhub_config.py"
mkdir -p "$JUPYTER_CONFIG_DIR"

if [ ! -f "$JUPYTER_CONFIG_FILE" ]; then
    jupyterhub --generate-config -f "$JUPYTER_CONFIG_FILE" >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
fi

grep -Fq "c.Spawner.default_url = '/lab'" "$JUPYTER_CONFIG_FILE" || \
    echo "c.Spawner.default_url = '/lab'     # jupyterlab 환경으로 보이도록" >> "$JUPYTER_CONFIG_FILE"
grep -Fq "c.Authenticator.allow_all = True" "$JUPYTER_CONFIG_FILE" || \
    echo "c.Authenticator.allow_all = True   # 모든 사용자가 접속하도록" >> "$JUPYTER_CONFIG_FILE"

# JupyterHub systemd 서비스 등록
JUPYTER_SERVICE_FILE="/etc/systemd/system/jupyterhub.service"
if [ ! -f "$JUPYTER_SERVICE_FILE" ]; then
    cat <<EOF > "$JUPYTER_SERVICE_FILE"
[Unit]
Description=JupyterHub
After=network.target

[Service]
User=root
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=$(command -v jupyterhub) -f $JUPYTER_CONFIG_FILE

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable jupyterhub.service
    systemctl start jupyterhub.service
fi

echo "JupyterHub, JupyterLab 설치 및 서비스 등록 완료" | tee -a "$INSTALL_LOG"


# --- LSA 설치 및 설정 스크립트 ---

echo "===== LSA 설치 시작 ====="

# 작업 디렉터리 생성 및 이동
mkdir -p /root/LSA
cd /root/LSA

# Broadcom LSA ZIP 다운로드 및 압축 해제
wget https://docs.broadcom.com/docs-and-downloads/008.012.007.000_MR7.32_LSA_Linux.zip

unzip -o 008.012.007.000_MR7.32_LSA_Linux.zip
cd webgui_rel
unzip -o LSA_Linux.zip
ls -l

# gcc_8.3.x 폴더로 이동 후 install.sh 자동 실행
cd ../gcc_8.3.x
yes | ./install.sh -s

echo "=== LSA install.sh 완료 ==="

# ----- LsiSASH 스크립트 별도 디렉터리에 배치 -----
mkdir -p /etc/lsisash
if [ -f LsiSASH ]; then
    cp -f LsiSASH /etc/lsisash/LsiSASH
    chmod +x /etc/lsisash/LsiSASH
else
    echo "[WARN] LsiSASH 스크립트를 찾을 수 없습니다. /etc/lsisash에 수동 복사 필요" 
fi

# OS별 방화벽 설정
case "$OS_FULL_ID" in
    rocky8|rocky9|rocky10|almalinux8|almalinux9|almalinux10)
        firewall-cmd --zone=public --add-service=http --permanent
        firewall-cmd --zone=public --add-port=2463/tcp --permanent
        firewall-cmd --reload
        ;;
    ubuntu2004|ubuntu2204|ubuntu2404)
        ufw allow http
        ufw allow 2463/tcp
        ufw reload
        ;;
esac

# ----- systemd 서비스 생성 (/etc/lsisash 경로 사용) -----
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
    echo "lsisash.service 서비스 등록 및 시작 완료"
else
    echo "lsisash.service 서비스가 이미 존재합니다."
fi

echo "===== LSA 설치 및 설정 완료 ====="


# --- 19. Dell OMSA 설치 ---
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
        ubuntu2004|ubuntu2204|ubuntu2404)
            echo "Ubuntu 계열 OMSA 설치" | tee -a "$INSTALL_LOG"
            ufw allow 1311/tcp

            echo 'deb http://linux.dell.com/repo/community/openmanage/10300/focal focal main' \
                > /etc/apt/sources.list.d/linux.dell.com.sources.list
            wget http://linux.dell.com/repo/pgp_pubkeys/0x1285491434D8786F.asc
            apt-key add 0x1285491434D8786F.asc
            apt-get -y update
            apt-get -y install srvadmin-all

            if [ ! -f /usr/lib/x86_64-linux-gnu/libssl.so ]; then
                ln -s /usr/lib/x86_64-linux-gnu/libssl.so.1.1 /usr/lib/x86_64-linux-gnu/libssl.so
            fi

            systemctl daemon-reload
            systemctl enable dsm_sa_datamgrd.service
            systemctl enable dsm_om_connsvc
            systemctl start dsm_sa_datamgrd.service
            systemctl start dsm_om_connsvc
            ;;
        *)
            echo "지원하지 않는 OS: $OS_FULL_ID" | tee -a "$INSTALL_LOG"
            ;;
    esac
else
    echo "OMSA가 이미 설치되어 있습니다." | tee -a "$INSTALL_LOG"
fi


echo "모든 과정이 완료되었습니다. 시스템을 재부팅합니다." | tee -a "$INSTALL_LOG"
# reboot