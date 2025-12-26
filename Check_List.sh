#!/bin/bash
#
# Copyright by Dasandata.co.ltd
# Modernized Check List - FIXED TEMPLATE (2025-12-26)
# 이 스크립트는 메인 설치 스크립트의 작업 결과를 최종 점검하고,
# 마지막에 rc.local에서 자기 실행 라인을 제거합니다.

LOG_DIR="/root/dasan_LOGS"
CHECKLIST_LOG="$LOG_DIR/Check_List.log"

mkdir -p "$LOG_DIR"
: > "$CHECKLIST_LOG"

log() { echo -e "$*" | tee -a "$CHECKLIST_LOG"; }

# --- OS 정보 탐지 ---
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_ID=$ID
  OS_FULL_ID="${ID}${VERSION_ID%%.*}"
else
  log "[ERROR] OS 정보를 확인할 수 없습니다."
  exit 1
fi

log "############################################################"
log "#             Linux Auto Script - CHECKLIST                #"
log "############################################################"
log ""
log "스크립트 실행 일시: $(date)"
log "OS: ${PRETTY_NAME:-$OS_ID}"
log "Kernel: $(uname -r)"
log "------------------------------------------------------------"
log ""

# 1. Nouveau 드라이버 비활성화 체크
log "##### 1. Nouveau Driver Disable Check #####"
if lsmod | grep -q '^nouveau'; then
  log "[FAIL] Nouveau 드라이버가 여전히 활성화되어 있습니다."
else
  log "[OK] Nouveau 드라이버가 비활성화되었습니다."
fi
(grep -R "blacklist nouveau" /etc/modprobe.d 2>/dev/null | head -n 3 || echo "[INFO] blacklist nouveau 항목 없음") | tee -a "$CHECKLIST_LOG"
log ""

# 2. 시스템 설정 (SELinux, Repository) 체크
log "##### 2. System Config Check #####"
case "$OS_ID" in
  rocky|almalinux)
    log "SELinux Status: $(getenforce 2>/dev/null || echo unknown)"
    (grep "^SELINUX=" /etc/selinux/config 2>/dev/null || echo "[INFO] SELinux 설정 파일 값 없음") | tee -a "$CHECKLIST_LOG"
    ;;
  ubuntu)
    log "APT Repository (mirror.kakao.com):"
    (grep -R "mirror.kakao.com" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || echo "[INFO] Kakao 미러 설정이 없습니다.") | tee -a "$CHECKLIST_LOG"
    ;;
esac
log ""

# 3. 방화벽 및 SSH 포트 변경 체크 (파이프 우선순위 오류 수정)
log "##### 3. Firewall & SSH Port Check #####"
if grep -qE '^\s*Port\s+7777\b' /etc/ssh/sshd_config 2>/dev/null; then
  log "[OK] SSH 포트가 7777로 변경되었습니다."
else
  log "[FAIL] SSH 포트가 변경되지 않았습니다."
fi

case "$OS_ID" in
  rocky|almalinux)
    log "Firewalld Status: $(systemctl is-active firewalld 2>/dev/null || echo unknown)"
    if command -v firewall-cmd >/dev/null 2>&1; then
      if firewall-cmd --list-ports 2>/dev/null | grep -q "7777/tcp"; then
        log "[OK] Firewalld에 7777/tcp 포트가 열려있습니다."
      else
        log "[FAIL] Firewalld에 7777/tcp 포트가 없습니다."
      fi
    else
      log "[INFO] firewall-cmd를 찾을 수 없습니다."
    fi
    ;;
  ubuntu)
    log "UFW Status: $(ufw status 2>/dev/null | grep -i Status || echo unknown)"
    if ufw status 2>/dev/null | grep -qE '7777/tcp\s+ALLOW'; then
      log "[OK] UFW에 7777/tcp 포트가 허용되었습니다."
    else
      log "[FAIL] UFW에 7777/tcp 포트가 없습니다."
    fi
    ;;
esac
log ""

# 4. 시간 동기화 (Chrony) 체크 (inactive/active 두 줄 찍히는 문제 수정)
log "##### 4. Time Sync (Chrony) Check #####"
log "Current Time: $(date)"

CHRONY_SVC=""
if systemctl list-unit-files 2>/dev/null | grep -q '^chronyd\.service'; then
  CHRONY_SVC="chronyd"
elif systemctl list-unit-files 2>/dev/null | grep -q '^chrony\.service'; then
  CHRONY_SVC="chrony"
fi

if [ -n "$CHRONY_SVC" ]; then
  log "Chrony Service Status(${CHRONY_SVC}): $(systemctl is-active "$CHRONY_SVC" 2>/dev/null || echo unknown)"
else
  log "[INFO] chrony/chronyd 서비스 유닛을 찾지 못했습니다."
fi

(timedatectl status 2>/dev/null | grep "Time zone" || echo "[INFO] 시간대 정보 없음") | tee -a "$CHECKLIST_LOG"
log ""

# 5. H/W 사양 리포트 존재 여부 체크 (경로 수정)
log "##### 5. H/W Spec Report Check #####"
HW_FILE_MAIN="$LOG_DIR/HWcheck.txt"
HW_FILE_OLD="/root/HWcheck.txt"

if [ -f "$HW_FILE_MAIN" ]; then
  log "[OK] H/W 체크 리포트($HW_FILE_MAIN)가 존재합니다."
elif [ -f "$HW_FILE_OLD" ]; then
  log "[OK] H/W 체크 리포트($HW_FILE_OLD)가 존재합니다. (구버전 경로)"
else
  log "[FAIL] H/W 체크 리포트가 생성되지 않았습니다."
fi
log ""

# 6. GPU, CUDA, CUDNN 체크 (cudaversion.txt 경로 정리)
log "##### 6. GPU, CUDA, CUDNN Check #####"
CUDA_FILE_MAIN="$LOG_DIR/cudaversion.txt"
CUDA_FILE_OLD="/root/cudaversion.txt"

CUDA_FILE=""
if [ -f "$CUDA_FILE_MAIN" ]; then
  CUDA_FILE="$CUDA_FILE_MAIN"
elif [ -f "$CUDA_FILE_OLD" ]; then
  CUDA_FILE="$CUDA_FILE_OLD"
fi

CUDA_VER=""
if [ -n "$CUDA_FILE" ]; then
  CUDA_VER="$(cat "$CUDA_FILE" 2>/dev/null | head -n 1)"
fi

if [ -n "$CUDA_VER" ] && [ "$CUDA_VER" != "No-GPU" ]; then
  if command -v nvidia-smi >/dev/null 2>&1; then
    log "[OK] nvidia-smi 명령어가 존재합니다."
    nvidia-smi -L 2>/dev/null | tee -a "$CHECKLIST_LOG"
  else
    log "[FAIL] nvidia-smi 명령어를 찾을 수 없습니다."
  fi

  if command -v nvcc >/dev/null 2>&1; then
    log "[OK] nvcc 명령어가 존재합니다."
    nvcc -V 2>/dev/null | grep "release" | tee -a "$CHECKLIST_LOG"
  else
    log "[FAIL] nvcc 명령어를 찾을 수 없습니다."
  fi
else
  log "[INFO] No-GPU 서버이거나 CUDA 버전 파일이 없어서 CUDA/CUDNN 점검을 건너뜁니다."
fi
log ""

# 7. Broadcom LSA 서비스 체크 (서비스가 아예 없는 경우 INFO 처리)
log "##### 7. LSA (Broadcom) Service Check #####"
if systemctl list-unit-files 2>/dev/null | grep -q '^lsisash\.service'; then
  if systemctl is-active --quiet lsisash.service; then
    log "[OK] lsisash.service가 활성화되어 있습니다."
  else
    log "[FAIL] lsisash.service가 비활성화 상태입니다."
  fi
else
  log "[INFO] lsisash.service 유닛이 없습니다. (LSA 미설치 또는 설치 실패)"
fi
log ""

# 8. Dell OMSA 서비스 체크
log "##### 8. OMSA (Dell) Service Check #####"
if dmidecode -s system-manufacturer 2>/dev/null | grep -iq "Dell"; then
  if systemctl list-unit-files 2>/dev/null | grep -q '^dsm_om_connsvc\.service'; then
    if systemctl is-active --quiet dsm_om_connsvc; then
      log "[OK] Dell OMSA(dsm_om_connsvc) 서비스가 활성화되어 있습니다."
    else
      log "[FAIL] Dell OMSA 서비스가 비활성화 상태입니다."
    fi
  else
    log "[FAIL] Dell 서버인데 dsm_om_connsvc.service 유닛이 없습니다."
  fi
else
  log "[INFO] Dell 서버가 아니므로 OMSA 설치를 건너뛰었습니다."
fi
log ""

# --- 최종 정리: rc.local에서 자동 실행 항목 제거 (realpath $0 제거하고 고정 문자열로 제거) ---
log "------------------------------------------------------------"
log "체크리스트 완료. 다음 부팅부터 이 스크립트는 실행되지 않습니다."

remove_line_from_file() {
  local file="$1"
  local needle="$2"
  [ -f "$file" ] || return 0

  if grep -Fq "$needle" "$file"; then
    grep -Fv "$needle" "$file" > "${file}.tmp" && mv -f "${file}.tmp" "$file"
    chmod +x "$file" 2>/dev/null || true
    return 0
  fi
  return 0
}

# OS별 rc.local 후보들 (둘 다 있으면 둘 다 정리)
RC_CANDIDATES=()
case "$OS_ID" in
  ubuntu)
    RC_CANDIDATES+=("/etc/rc.local" "/etc/rc.d/rc.local")
    ;;
  rocky|almalinux)
    RC_CANDIDATES+=("/etc/rc.d/rc.local" "/etc/rc.local")
    ;;
esac

TARGET_LINE="bash /root/LAS/Check_List.sh"

for rc in "${RC_CANDIDATES[@]}"; do
  if [ -f "$rc" ]; then
    remove_line_from_file "$rc" "$TARGET_LINE"
    # 혹시 공백/다른 호출형태가 있어도 확실히 제거
    grep -vE 'Check_List\.sh' "$rc" > "${rc}.tmp" && mv -f "${rc}.tmp" "$rc"
    chmod +x "$rc" 2>/dev/null || true
    log "$rc에서 Check_List 자동 실행 항목을 제거했습니다."
  fi
done

log "############################################################"
exit 0
