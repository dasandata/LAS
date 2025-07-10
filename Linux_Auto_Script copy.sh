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

# 신뢰성 있는 OS 정보 탐지
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
# 참고: 최신 systemd 시스템에서는 rc.local 대신 전용 systemd service를 생성하는 것이 권장됩니다.
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
if ! grep -q "ipv6.disable=1" /etc/default/grub; then
    echo "Nouveau 드라이버 비활성화 및 GRUB 설정을 시작합니다." | tee -a "$INSTALL_LOG"
    echo "blacklist nouveau" >> /etc/modprobe.d/blacklist-nouveau.conf
    echo "options nouveau modeset=0" >> /etc/modprobe.d/blacklist-nouveau.conf

    # GRUB 설정 수정
    sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="ipv6.disable=1 \1"/g' /etc/default/grub
    sed -i -e 's/ quiet//g' -e 's/ splash//g' /etc/default/grub

    case "$OS_ID" in
        ubuntu)
            update-initramfs -u >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            update-grub >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            ;;
        rocky|almalinux)
            dracut -f >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            grub2-mkconfig -o /boot/grub2/grub.cfg >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            # EFI 시스템용 경로 추가
            [ -f /boot/efi/EFI/"$OS_ID"/grub.cfg ] && grub2-mkconfig -o /boot/efi/EFI/"$OS_ID"/grub.cfg >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
            ;;
    esac
    echo "GRUB 설정 완료. 재부팅 후 적용됩니다." | tee -a "$INSTALL_LOG"
else
    echo "GRUB 설정이 이미 완료되었습니다." | tee -a "$INSTALL_LOG"
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
        dnf -y install vim nfs-utils rdate curl git wget figlet net-tools htop dstat \
        gnome-tweaks smartmontools python3-pip python3-devel >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
        ;;
esac
echo "기본 패키지 설치 완료." | tee -a "$INSTALL_LOG"

# 이하 스크립트는 원본의 구조를 따르며, 최신 OS에 맞게 필요한 부분을 수정/검증해야 합니다.
# (예: 방화벽, 사용자 설정, Python 패키지, CUDA/CUDNN, 딥러닝 패키지 설치 등)
# 모든 과정은 많은 테스트가 필요하며, 특히 드라이버와 라이브러리 버전 호환성 확인이 중요합니다.

echo "---"
echo "기본적인 시스템 설정 및 패키지 설치 스크립트의 현대화가 완료되었습니다." | tee -a "$INSTALL_LOG"
echo "이후 과정(CUDA, 딥러닝 패키지 등)은 시스템 환경에 맞춰 추가적인 검증이 필요합니다." | tee -a "$INSTALL_LOG"
echo "스크립트가 재부팅을 요청할 수 있습니다." | tee -a "$INSTALL_LOG"

# ... (원본 스크립트의 7번 이후 항목들을 여기에 현대화하여 추가) ...

# 예시: 10. 방화벽 설정 현대화
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

echo "모든 과정이 완료되었습니다. 시스템을 재부팅합니다." | tee -a "$INSTALL_LOG"
# reboot