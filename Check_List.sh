#!/bin/bash
# Copyright by Dasandata.co.ltd
# http://www.dasandata.co.kr
# Modernized Check List - 2025

LOGFILE="/root/Auto_Install_Log.txt"
> "$LOGFILE"

echo ""  | tee -a "$LOGFILE"
echo "You have run Check List Script"  | tee -a "$LOGFILE"
echo "Copyright by Dasandata.co.ltd"  | tee -a "$LOGFILE"
echo "https://www.dasandata.co.kr"    | tee -a "$LOGFILE"
echo ""  | tee -a "$LOGFILE"

OS_ID="$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')"
OS_VERSION_MAJOR="$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | cut -d. -f1 | tr -d '"')"
OS_FULL_ID="${OS_ID}${OS_VERSION_MAJOR}"

# 1. Nouveau 및 GRUB 체크
echo "##### 1. Nouveau, GRUB Check Start #####"  | tee -a "$LOGFILE"
if [ -f /etc/default/grub ]; then
  cat /etc/default/grub | grep "linux" >> "$LOGFILE"
fi
echo "=== blacklist nouveau check ===" | tee -a "$LOGFILE"
grep "blacklist nouveau" /etc/modprobe.d/*.conf 2>/dev/null >> "$LOGFILE"
echo "=== options nouveau modeset=0 check ===" | tee -a "$LOGFILE"
grep "options nouveau modeset=0" /etc/modprobe.d/*.conf 2>/dev/null >> "$LOGFILE"
echo "##### Nouveau, GRUB Check Complete #####"  | tee -a "$LOGFILE"

# 2. SELinux 및 저장소 미러/변경 체크
case "$OS_ID" in
  rocky|almalinux)
    echo "##### 2. SELINUX Check #####"  | tee -a "$LOGFILE"
    getenforce  >> "$LOGFILE"
    grep "^SELINUX=" /etc/selinux/config >> "$LOGFILE"
    echo "##### SELINUX Check Complete #####"  | tee -a "$LOGFILE"
    ;;
  ubuntu)
    echo "##### 2. Repository Check #####"  | tee -a "$LOGFILE"
    grep mirror.kakao.com /etc/apt/sources.list  >> "$LOGFILE"
    echo "##### Repository Check Complete #####"  | tee -a "$LOGFILE"
    ;;
esac

# 3. 기본 패키지 체크
echo "##### 3. Package Install Check #####"  | tee -a "$LOGFILE"
uname -r >> "$LOGFILE"
# htop, kernel-headers, kernel-devel
case "$OS_ID" in
  rocky|almalinux)
    rpm -qa | grep -E 'htop|kernel-headers|kernel-devel' >> "$LOGFILE"
    ;;
  ubuntu)
    dpkg -l | grep -i htop >> "$LOGFILE"
    dpkg -l | grep -i linux-headers >> "$LOGFILE"
    ;;
esac
echo "##### Package Check Complete #####"  | tee -a "$LOGFILE"

# 4. 프로필/alias, 히스토리 체크
echo "##### 4. Profile Check #####"  | tee -a "$LOGFILE"
grep "Dasandata" /etc/profile >> "$LOGFILE"
grep "alias vi='vim'" /etc/profile >> "$LOGFILE"
grep "HISTTIMEFORMAT" /etc/profile >> "$LOGFILE"
grep PS1 /root/.bashrc >> "$LOGFILE"
echo "##### Profile Check Complete #####"  | tee -a "$LOGFILE"

# 5. 시간동기화 체크
echo "##### 5. Time Check #####"  | tee -a "$LOGFILE"
date  >> "$LOGFILE"
hwclock >> "$LOGFILE"
timedatectl status >> "$LOGFILE" 2>/dev/null
echo "##### Time Check Complete #####"  | tee -a "$LOGFILE"

# 6. Python/Pip 체크
echo "##### 6. Python & pip Version Check #####" | tee -a "$LOGFILE"
/usr/bin/python3 -V >> "$LOGFILE" 2>&1
python3 -m pip --version >> "$LOGFILE" 2>&1
echo "##### Python Version Check Complete #####"  | tee -a "$LOGFILE"

# 7. 방화벽 상태/포트 오픈 체크
echo "##### 7. Firewall Check #####" | tee -a "$LOGFILE"
case "$OS_ID" in
  rocky|almalinux)
    systemctl is-active firewalld >> "$LOGFILE"
    firewall-cmd --list-all >> "$LOGFILE"
    ;;
  ubuntu)
    systemctl is-active ufw >> "$LOGFILE"
    ufw status >> "$LOGFILE"
    ;;
esac
echo "##### Firewall Check Complete #####"  | tee -a "$LOGFILE"

# 8. HW 사양 체크리포트 첨부
echo "##### 8. HW Spec Check #####"  | tee -a "$LOGFILE"
if [ -f /root/HWcheck.txt ]; then
  cat /root/HWcheck.txt >> "$LOGFILE"
else
  echo "[WARN] HWcheck.txt가 존재하지 않습니다." >> "$LOGFILE"
fi
echo "##### HW Spec Check Complete #####"  | tee -a "$LOGFILE"

# 9. LSA(LsiSASH) 서비스 및 포트 상태
echo "##### 9. LSA(LsiSASH) Service Check #####" | tee -a "$LOGFILE"
systemctl status lsisash.service >> "$LOGFILE" 2>&1
case "$OS_ID" in
  rocky|almalinux)
    firewall-cmd --list-ports | grep 2463 >> "$LOGFILE"
    netstat -ntlp | grep 2463 >> "$LOGFILE" 2>/dev/null
    ;;
  ubuntu)
    ufw status | grep 2463 >> "$LOGFILE"
    ss -ntlp | grep 2463 >> "$LOGFILE" 2>/dev/null
    ;;
esac
echo "##### LSA Check Complete #####" | tee -a "$LOGFILE"

# 10. OMSA(Dell OpenManage) 서비스
echo "##### 10. OMSA (OpenManage) Service Check #####" | tee -a "$LOGFILE"
systemctl status dsm_om_connsvc >> "$LOGFILE" 2>&1
case "$OS_ID" in
  rocky|almalinux)
    firewall-cmd --list-ports | grep 1311 >> "$LOGFILE"
    ;;
  ubuntu)
    ufw status | grep 1311 >> "$LOGFILE"
    ;;
esac
echo "##### OMSA Service Check Complete #####" | tee -a "$LOGFILE"

# 11. R, RStudio, JupyterHub 서비스/설치 체크
echo "##### 11. R/RStudio/JupyterLab Install & Service Check #####" | tee -a "$LOGFILE"
case "$OS_ID" in
  rocky|almalinux)
    rpm -qa | grep R- | grep -v library >> "$LOGFILE"
    rpm -qa | grep rstudio-server >> "$LOGFILE"
    ;;
  ubuntu)
    dpkg -l | grep r-base >> "$LOGFILE"
    dpkg -l | grep rstudio-server >> "$LOGFILE"
    ;;
esac
systemctl status jupyterhub.service >> "$LOGFILE" 2>&1
echo "##### R/RStudio/JupyterHub Check Complete #####" | tee -a "$LOGFILE"

# 12. GPU 및 CUDA, CUDNN 체크(GPU 서버일 때)
if lspci | grep -iq nvidia; then
  echo "##### 12. GPU, CUDA, CUDNN Check #####" | tee -a "$LOGFILE"
  nvidia-smi >> "$LOGFILE" 2>&1
  nvcc -V >> "$LOGFILE" 2>&1
  # CUDA/CUDNN lib 설치상태
  case "$OS_ID" in
    rocky|almalinux)
      rpm -qa | grep cuda >> "$LOGFILE"
      rpm -qa | grep libcudnn >> "$LOGFILE"
      ;;
    ubuntu)
      dpkg -l | grep cuda >> "$LOGFILE"
      dpkg -l | grep libcudnn >> "$LOGFILE"
      ;;
  esac
  echo "##### GPU, CUDA, CUDNN Check Complete #####" | tee -a "$LOGFILE"
fi

echo "" | tee -a "$LOGFILE"
echo "##### 전체 체크리스트 완료 #####" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"
echo "상세 내역은 $LOGFILE 파일을 확인하세요." | tee -a "$LOGFILE"