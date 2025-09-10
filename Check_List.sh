#!/bin/bash
#
# Copyright by Dasandata.co.ltd
# Modernized Check List - 2025-09-10
# 이 스크립트는 메인 설치 스크립트의 작업 결과를 최종 점검합니다.

LOG_DIR="/root/LAS_LOGS"
CHECKLIST_LOG="$LOG_DIR/Check_List.log"
# 로그 파일 초기화
> "$CHECKLIST_LOG"

# --- 기본 정보 로깅 ---
echo "############################################################" | tee -a "$CHECKLIST_LOG"
echo "#             Linux Auto Script - CHECKLIST                #" | tee -a "$CHECKLIST_LOG"
echo "############################################################" | tee -a "$CHECKLIST_LOG"
echo "" | tee -a "$CHECKLIST_LOG"
echo "스크립트 실행 일시: $(date)" | tee -a "$CHECKLIST_LOG"
echo "상세 내역은 $CHECKLIST_LOG 파일에 저장됩니다."
echo ""

# --- OS 정보 탐지 ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_FULL_ID="${ID}${VERSION_ID%%.*}"
else
    echo "[ERROR] OS 정보를 확인할 수 없습니다." | tee -a "$CHECKLIST_LOG"
    exit 1
fi
echo "OS: $PRETTY_NAME" | tee -a "$CHECKLIST_LOG"
echo "Kernel: $(uname -r)" | tee -a "$CHECKLIST_LOG"
echo "------------------------------------------------------------" | tee -a "$CHECKLIST_LOG"


# 1. Nouveau 드라이버 비활성화 체크
echo "##### 1. Nouveau Driver Disable Check #####" | tee -a "$CHECKLIST_LOG"
if lsmod | grep -q nouveau; then
    echo "[FAIL] Nouveau 드라이버가 여전히 활성화되어 있습니다." | tee -a "$CHECKLIST_LOG"
else
    echo "[OK] Nouveau 드라이버가 비활성화되었습니다." | tee -a "$CHECKLIST_LOG"
fi
(grep "blacklist nouveau" /etc/modprobe.d/*nouveau*.conf || echo "[INFO] blacklist-nouveau.conf 항목 없음") | tee -a "$CHECKLIST_LOG"
echo "" | tee -a "$CHECKLIST_LOG"


# 2. 시스템 설정 (SELinux, Repository) 체크
echo "##### 2. System Config Check #####" | tee -a "$CHECKLIST_LOG"
case "$OS_ID" in
  rocky|almalinux)
    echo "SELinux Status: $(getenforce)" | tee -a "$CHECKLIST_LOG"
    (grep "^SELINUX=" /etc/selinux/config || echo "[INFO] SELinux 설정 파일 값 없음")| tee -a "$CHECKLIST_LOG"
    ;;
  ubuntu)
    echo "APT Repository (mirror.kakao.com):" | tee -a "$CHECKLIST_LOG"
    (grep "mirror.kakao.com" /etc/apt/sources.list /etc/apt/sources.list.d/*.sources 2>/dev/null || echo "[INFO] Kakao 미러 설정이 없습니다.") | tee -a "$CHECKLIST_LOG"
    ;;
esac
echo "" | tee -a "$CHECKLIST_LOG"


# 3. 방화벽 및 SSH 포트 변경 체크
echo "##### 3. Firewall & SSH Port Check #####" | tee -a "$CHECKLIST_LOG"
(grep "^Port 7777" /etc/ssh/sshd_config && echo "[OK] SSH 포트가 7777로 변경되었습니다.") || echo "[FAIL] SSH 포트가 변경되지 않았습니다." | tee -a "$CHECKLIST_LOG"
case "$OS_ID" in
  rocky|almalinux)
    echo "Firewalld Status: $(systemctl is-active firewalld)" | tee -a "$CHECKLIST_LOG"
    (firewall-cmd --list-ports | grep -q "7777/tcp" && echo "[OK] Firewalld에 7777/tcp 포트가 열려있습니다.") || echo "[FAIL] Firewalld에 7777/tcp 포트가 없습니다." | tee -a "$CHECKLIST_LOG"
    ;;
  ubuntu)
    echo "UFW Status: $(ufw status | grep Status)" | tee -a "$CHECKLIST_LOG"
    (ufw status | grep -q "7777/tcp.*ALLOW" && echo "[OK] UFW에 7777/tcp 포트가 허용되었습니다.") || echo "[FAIL] UFW에 7777/tcp 포트가 없습니다." | tee -a "$CHECKLIST_LOG"
    ;;
esac
echo "" | tee -a "$CHECKLIST_LOG"


# 4. 시간 동기화 (Chrony) 체크
echo "##### 4. Time Sync (Chrony) Check #####" | tee -a "$CHECKLIST_LOG"
echo "Current Time: $(date)" | tee -a "$CHECKLIST_LOG"
echo "Chrony Service Status: $(systemctl is-active chrony 2>/dev/null || systemctl is-active chronyd 2>/dev/null)" | tee -a "$CHECKLIST_LOG"
(timedatectl status | grep "Time zone" || echo "[INFO] 시간대 정보 없음") | tee -a "$CHECKLIST_LOG"
echo "" | tee -a "$CHECKLIST_LOG"


# 5. H/W 사양 리포트 존재 여부 체크
echo "##### 5. H/W Spec Report Check #####" | tee -a "$CHECKLIST_LOG"
if [ -f /root/HWcheck.txt ]; then
  echo "[OK] H/W 체크 리포트(/root/HWcheck.txt)가 존재합니다." | tee -a "$CHECKLIST_LOG"
else
  echo "[FAIL] H/W 체크 리포트가 생성되지 않았습니다." | tee -a "$CHECKLIST_LOG"
fi
echo "" | tee -a "$CHECKLIST_LOG"


# 6. GPU, CUDA, CUDNN 체크
if [ -f /root/cudaversion.txt ] && [ "$(cat /root/cudaversion.txt)" != "No-GPU" ]; then
    echo "##### 6. GPU, CUDA, CUDNN Check #####" | tee -a "$CHECKLIST_LOG"
    if command -v nvidia-smi &> /dev/null; then
        echo "[OK] nvidia-smi 명령어가 존재합니다." | tee -a "$CHECKLIST_LOG"
        nvidia-smi -L | tee -a "$CHECKLIST_LOG"
    else
        echo "[FAIL] nvidia-smi 명령어를 찾을 수 없습니다." | tee -a "$CHECKLIST_LOG"
    fi

    if command -v nvcc &> /dev/null; then
        echo "[OK] nvcc 명령어가 존재합니다." | tee -a "$CHECKLIST_LOG"
        nvcc -V | grep "release" | tee -a "$CHECKLIST_LOG"
    else
        echo "[FAIL] nvcc 명령어를 찾을 수 없습니다." | tee -a "$CHECKLIST_LOG"
    fi
    echo "" | tee -a "$CHECKLIST_LOG"
else
    echo "##### 6. GPU, CUDA, CUDNN Check #####" | tee -a "$CHECKLIST_LOG"
    echo "[INFO] No-GPU 서버이므로 CUDA/CUDNN 설치를 건너뛰었습니다." | tee -a "$CHECKLIST_LOG"
    echo "" | tee -a "$CHECKLIST_LOG"
fi


# 7. Broadcom LSA 서비스 체크
echo "##### 7. LSA (Broadcom) Service Check #####" | tee -a "$CHECKLIST_LOG"
(systemctl is-active --quiet lsisash.service && echo "[OK] lsisash.service가 활성화되어 있습니다.") || echo "[FAIL] lsisash.service가 비활성화 상태입니다." | tee -a "$CHECKLIST_LOG"
echo "" | tee -a "$CHECKLIST_LOG"


# 8. Dell OMSA 서비스 체크
echo "##### 8. OMSA (Dell) Service Check #####" | tee -a "$CHECKLIST_LOG"
if dmidecode -s system-manufacturer | grep -iq "Dell"; then
    (systemctl is-active --quiet dsm_om_connsvc && echo "[OK] Dell OMSA(dsm_om_connsvc) 서비스가 활성화되어 있습니다.") || echo "[FAIL] Dell OMSA 서비스가 비활성화 상태입니다." | tee -a "$CHECKLIST_LOG"
else
    echo "[INFO] Dell 서버가 아니므로 OMSA 설치를 건너뛰었습니다." | tee -a "$CHECKLIST_LOG"
fi
echo "" | tee -a "$CHECKLIST_LOG"


# --- 최종 정리: rc.local에서 자동 실행 항목 제거 ---
echo "------------------------------------------------------------" | tee -a "$CHECKLIST_LOG"
echo "체크리스트 완료. 다음 부팅부터 이 스크립트는 실행되지 않습니다." | tee -a "$CHECKLIST_LOG"

case "$OS_ID" in
    ubuntu) RC_PATH="/etc/rc.local" ;;
    rocky|almalinux) RC_PATH="/etc/rc.d/rc.local" ;;
esac

if [ -n "$RC_PATH" ] && [ -f "$RC_PATH" ]; then
    # 자기 자신(/root/LAS/Check_List.sh)을 실행하는 라인을 찾아 삭제
    sed -i "\|bash $(realpath "$0")|d" "$RC_PATH"
    echo "$RC_PATH에서 Check_List 자동 실행 항목을 제거했습니다." | tee -a "$CHECKLIST_LOG"
fi

echo "############################################################" | tee -a "$CHECKLIST_LOG"

