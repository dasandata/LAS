# 다산데이타 LISR 스크립트 설치 매뉴얼 2025-11
다산데이타 장비 출고시 설치되는 Ubuntu 24.04 설치 표준안 입니다. 
별도의 요청사항이 없는 경우 기본적으로 아래 절차에 따라 자동 스크립트 설치가 진행 됩니다.  
이 문서는 스크립트의 수동 설치 가이드 입니다.
***

## #목차

### ===== 기본 버전 설치 진행 순서 =====

[1. 변수 선언](Ubuntu_24_Install_Guide.md#-1-변수-선언)  

[2. nouveau 끄기 및 grub 설정](Ubuntu_24_Install_Guide.md#-2-nouveau-끄기-및-grub-설정)  

[3. 시스템 설정](Ubuntu_24_Install_Guide.md#-3-시스템-설정)  

[4. 기본 패키지 설치](Ubuntu_24_Install_Guide.md#-4-기본-패키지-설치)  

[5. 프로필 설정](Ubuntu_24_Install_Guide.md#-5-프로필-설정)  

[6. 서버 시간 동기화](Ubuntu_24_Install_Guide.md#-6-서버-시간-동기화)  

[7. 파이썬 설치](Ubuntu_24_Install_Guide.md#-7-파이썬-설치)  

[8. 방화벽 설정](Ubuntu_24_Install_Guide.md#-8-방화벽-설정)  

[9. H/W 사양 체크](Ubuntu_24_Install_Guide.md#-9-HW-사양-체크)  

### ===== GPU 버전 설치 진행 순서 ===== 

[10. CUDA,CUDNN Repo 설치](Ubuntu_24_Install_Guide.md#-10-CUDACUDNN-Repo-설치)

[11. CUDA 설치 및 PATH 설정](Ubuntu_24_Install_Guide.md#-11-CUDA-설치-및-PATH-설정)

[12. CUDNN 설치](Ubuntu_24_Install_Guide.md#-12-CUDNN-설치)

[13. 딥러닝 패키지 설치](Ubuntu_24_Install_Guide.md#-13-딥러닝-패키지-설치)

### =====  Raid manager 설치 진행 순서 ===== 

[14-1. Raid manager MSM 설치](Ubuntu_24_Install_Guide.md#-14-1-MSM-설치)

[14-2. Raid manager LSA 설치](Ubuntu_24_Install_Guide.md#-14-2-LSA-설치)

### ===== Dell 서버 전용 설치 순서 =====

[15. Dell 전용 OMSA설치](Ubuntu_24_Install_Guide.md#-15-Dell-전용-OMSA설치)
***
## # 범례(변수).
- <내용>: 상황에 따라 변경이 필요한 내용을 표현 합니다.  
- ${변수명} : 반복되어 사용되는 부분이 있을 때 사용되는 변수 입니다. 
***
## # 팁.
- 명령을 실행시킬때, 명령어 박스 단위로 복사하여 터미널에 붙여 넣으면 됩니다.  
- 박스가 분리되어 있는 경우 분리된 단위로 복사하여 붙여 넣어야 합니다.

### # 리눅스 설치시 IP 와 HOSTNAME 은 수동으로 미리 설정 한다.
- 처음 설치 할때부터 고정 IP를 설정하고 HOSTNAME을 정의 하는 것을 권장 합니다.
- IPv6 설정은 설치 시 OFF 하시는걸 권장합니다.

### # 터미널을 통해 리눅스가 새로 설치된 장비에 로그인 합니다.

- MobaXterm (리눅스 접속, X11 Forwading, File 송수신)  
- https://mobaxterm.mobatek.net/download.html  

#### # SSH 사용 원격 접속 방법.
```bash
ssh <사용자 계정>@<IP 주소>
```

### # 관리자(root) 로 전환.
```bash
# sudo -i
# 또는
# su -
```
### # sudo -i 와 su - 의 차이점
- sudo -i 는 sudo 권한이 있는 사용자가, 사용자의 암호를 사용해서 root 권한으로 명령을 실행 하는 것 입니다.  
- sudo -i 는 root 의 패스워드를 몰라도 root 권한의 명령을 수행할 수 있습니다.  
- su - 는 sudo 권한과 관계 없이 root 의 암호를 사용해서 root 계정으로 전환 하는 것 입니다.    
- 재접속 없이 다른 사용자 계정으로 전환 할 수 있는 명령은 아래와 같이 사용 합니다. 
- su  -  abcd  
***

### # [1. 변수 선언](#목차)
#### ## 각 변수는 사용하기 전 선언하도록 작성되어 있습니다.
#### ## 여기서는 어떤 변수가 사용되는지 확인만 하도록 합니다.
```bash
# 설치하려는 서버의 종류를 확인 합니다. (Dell, Supermicro, 일반PC 등)
VENDOR=$(dmidecode -s system-manufacturer | awk '{print$1}')

# 지금 작동중인 네트워크 인터페이스 명을 확인 후 NIC 변수로 적용합니다.
NIC=$(ip -o -4 route show to default | awk '{print $5}')

# 현재 설치된 OS의 종류를 확인 합니다. (ex: centos, ubuntu, rocky)
OS_ID=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"' | tr '[A-Z]' '[a-z]')

# ubuntu의 정확한 버전을 확인 합니다.
OS_VERSION_MAJOR=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"' | cut -d'.' -f1)

# OS ID와 주 버전을 조합하여 최종 OS 식별자를 만듭니다. (ex: rocky8, ubuntu22)
OS_FULL_ID="${OS_ID}${OS_VERSION_MAJOR}"

# CUDA 설치 버전을 중 선택하여 CUDAV라는 변수로 사용합니다.
select CUDAV in 11-8 12-5 12-6 12-8 12-9 13-0 No-GPU ; do echo "Select CUDA Version : $CUDAV" ; break; done
```

### # [2. nouveau 끄기 및 grub 설정](#목차)
#### ## 부팅시 화면에 부팅 기록 출력, IPv6 비활성화, nouveau 비활성화를 위해 진행 합니다.

```bash
# Nvidia Driver 와 호환성 문제가 있는 nouveau 비활성화 
echo "blacklist nouveau"         >> /etc/modprobe.d/nouveau_disable.conf
echo "options nouveau modeset=0" >> /etc/modprobe.d/nouveau_disable.conf

# 변경된 내용으로 initramfs 및 grub 재설정
update-initramfs -u && update-grub
```

### # [3. 시스템 설정 ](#목차)
#### ## Ubuntu는 기존 저장소 속도 최적화를 위해 변경 합니다.

```bash
# 기존 저장소 주소보다 빠른 mirror.kakao.com 으로 변경
sed -i 's|http://kr.archive.ubuntu.com/ubuntu/|http://mirror.kakao.com/ubuntu/|g' /etc/apt/sources.list.d/ubuntu.sources
sed -i 's|http://security.ubuntu.com/ubuntu/|http://mirror.kakao.com/ubuntu/|g' /etc/apt/sources.list.d/ubuntu.sources
cat /etc/apt/sources.list.d/ubuntu.sources | grep -v "#\|^$"
```

### # [4. 기본 패키지 설치](#목차)
#### ## 서버 기본 설정에 필요한 패키지를 설치 합니다.
#### ## 필요없는 서비스를 disable 합니다 (장비에 따라 존재하지 않는 서비스도 있습니다.)

```bash
apt-get update
apt-get -y install build-essential snapd firefox vim nfs-common rdate xauth curl git wget figlet net-tools htop
apt-get -y install util-linux-extra smartmontools tmux xfsprogs aptitude lvm2 dstat npm ntfs-3g 
apt-get -y install gnome-tweaks dconf-editor gnome-settings-daemon metacity nautilus gnome-terminal
apt-get -y install install ipmitool python3-pip python3-dev

apt-get -y install ubuntu-desktop
systemctl set-default multi-user.target

systemctl mask network-online.target
```

### # [5. 프로필 설정](#목차)
#### ## 사용자 편의를 위한 설정을 진행 합니다.
#### ## alias, prompt-color, History Size, History date

```bash
# alias 설정
cat << EOF >> /etc/profile
# Add by Dasandata
alias vi='vim'
alias ls='ls --color=auto'
alias ll='ls -lh'
alias grep='grep --color=auto'
EOF

# History 시간표시 및 프롬프트 색상 변경
cat << EOF >> /etc/profile
# Add Timestamp to .bash_history
export HISTTIMEFORMAT="20%y/%m/%d %T "
EOF

echo "export PS1='\[\e[1;46;30m\][\u@\h:\W]\\$\[\e[m\] '"   >>  /root/.bashrc
echo "export PS1='\[\e[1;47;30m\][\u@\h:\W]\\$\[\e[m\] '"   >>  /home/temp_id/.bashrc

# 변경사항 적용 및 불러오기
source  /etc/profile
source  /root/.bashrc
echo $HISTSIZE
```

### # [6. 서버 시간 동기화](#목차)
#### ## 서버 및 HW 시간을 동기화 합니다.

```bash
apt-get -y install chrony

sed -i 's|^pool .* iburst|pool kr.pool.ntp.org iburst|' /etc/chrony/chrony.conf
systemctl enable --now chrony

# 시간대 한국 표준시로 설정
timedatectl set-timezone Asia/Seoul
chronyc makestep
chronyc sources -v
timedatectl status

# 현재 시간과 동일한지 확인
date
hwclock
```

### # [7. 파이썬 설치](#목차)

```bash
여기선 사용하지 않습니다.
```

### # [8. 방화벽 설정](#목차)

```bash
systemctl start ufw
systemctl enable ufw
yes | ufw enable
ufw default deny
ufw allow 22/tcp 
ufw allow 7777/tcp 

## R Server port
ufw allow 8787/tcp 

## JupyterHub port
ufw allow 8000/tcp

sed -i 's/#Port 22/Port 7777/g' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
echo "AddressFamily inet" >> /etc/ssh/sshd_config
systemctl restart sshd
```


### # [9. H/W 사양 체크](#목차)

```bash
# 기본적인 시스템 사양 체크를 진행합니다.
dmidecode --type system | grep -v "^$\|#\|SMBIOS\|Handle\|Not"
lscpu | grep -v "Flags\|NUMA|Vulnerability"
dmidecode --type 16 | grep -v "dmidecode\|SMBIOS\|Handle"
dmidecode --type memory | grep "Number Of Devices\|Size\|Locator\|Clock\|DDR\|Rank" | grep -v "No\|Unknown"
grep MemTotal /proc/meminfo
free -h
lspci | grep -i vga
lspci | grep -i nvidia
dmidecode | grep NIC
lspci | grep -i eth
lspci | grep -i communication
dmesg | grep NIC
dmidecode --type 39  | grep "System\|Name:\|Capacity"
blkid
lsblk
uname -a
```
***
<br/>

## ## 아래 부분을 진행 하기 전에 위 사항들이 적용 될 수 있게 재부팅을 진행 합니다.

```bash
reboot
```
<br/>

***

### ===== GPU 버전 설치 진행 순서 ===== 
#### ### 아래 10 ~ 12 항목의 경우 Nvidia-GPU가 존재할 경우 진행 합니다.

### # [10. CUDA,CUDNN Repo 설치](#목차)

```bash
# 사용할 CUDA 버전을 선택합니다. (22.04는 11.7만 지원됨)
select CUDAV in 12-8 12-9 13-0 No-GPU ; do echo "Select CUDA Version : $CUDAV" ; break; done

# 자세한 Ubuntu 버전을 변수로 선언합니다.
OS_ID=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"' | tr '[A-Z]' '[a-z]')
OS_VERSION_MAJOR=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"' | cut -d'.' -f1)
OS_FULL_ID="${OS_ID}${OS_VERSION_MAJOR}"


# Nvidia 저장소 생성 (Cuda,cudnn 설치를 위해)
apt-get -y install sudo gnupg
apt-key adv --fetch-keys "https://developer.download.nvidia.com/compute/cuda/repos/"${OS_FULL_ID}04"/x86_64/3bf863cc.pub"

sh -c 'echo "deb https://developer.download.nvidia.com/compute/cuda/repos/'${OS_FULL_ID}04'/x86_64 /" > /etc/apt/sources.list.d/nvidia-cuda.list'

apt-get update
```

### # [11. CUDA 설치 및 PATH 설정](#목차)

```bash
# CUDA 설치
apt-get -y install cuda-$CUDAV

# Driver 설치
ubuntu-drivers autoinstall

# profile에 PATH 설정시에는 cuda-11-7의 형식이 아닌 cuda-11.7 같은 형식으로 변경되어야 합니다.
CUDAV_U="${CUDAV/-/.}"

# cuda 설치 및 설치된 cuda를 사용하기 위해 경로 설정값을 profile에 입력
echo "" >> /etc/profile
echo "### ADD Cuda $CUDAV_U PATH" >> /etc/profile
echo "export PATH=/usr/local/cuda-$CUDAV_U/bin:/usr/local/cuda-$CUDAV_U/include:\$PATH" >> /etc/profile
echo "export LD_LIBRARY_PATH=/usr/local/cuda-$CUDAV_U/lib64:/usr/local/cuda/extras/CUPTI/:\$LD_LIBRARY_PATH" >> /etc/profile
echo "export CUDA_HOME=/usr/local/cuda-$CUDAV_U" >> /etc/profile
echo "export CUDA_INC_DIR=/usr/local/cuda-$CUDAV_U/include" >> /etc/profile

# 지속성 모드 On, 변경된 PATH 적용
nvidia-smi -pm 1
systemctl enable nvidia-persistenced
source /etc/profile
source /root/.bashrc
```

### # [12. CUDNN 설치](#목차)

```bash

CUDA_MAJOR=${CUDAV%%-*}

apt-get -y install \
libcudnn9-cuda-${CUDA_MAJOR} \
libcudnn9-dev-cuda-${CUDA_MAJOR} \
libcudnn9-headers-cuda-${CUDA_MAJOR} \
libcudnn9-samples
```

### # [13. 딥러닝 패키지 설치](#목차)
#### ## JupyterHub는 마지막 설정이 동일하여 마지막에 같이 서술하였습니다.
#### ## 마지막 설정에 사용되는 파일은 Git에 LAS 밑에 존재합니다.

```bash
# 딥러닝 패키지 (R, R-Server, JupyterHub) 를 설치 합니다.
# JupyterHub에 작업 중 사용되는 파일들은 LISR에 존재하므로 git을 통해 Pull 하고 사용해야 합니다.

## R,R-studio install
apt get -y install r-base libcurl4-openssl-dev libxml2-dev

wget -O /tmp/rstudio-server-latest.deb https://download2.rstudio.org/server/jammy/amd64/rstudio-server-2025.05.1-513-amd64.deb
apt -y install /tmp/rstudio-server-latest.deb
rm -f /tmp/rstudio-server-latest.deb

## JupyterHub install
python3 -m pip install --upgrade pip setuptools wheel
python3 -m pip install jupyterhub jupyterlab notebook

apt-get -y purge nodejs libnode72

curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 
apt-get -y install nodejs default-jre 
npm install -g configurable-http-proxy 

## Pycharm install
snap install pycharm-community --classic
```


```bash
## JupyterHub 마무리 작업.

mkdir -p /etc/jupyterhub

jupyterhub --generate-config -f /etc/jupyterhub/jupyterhub_config.py

echo "c.Spawner.default_url = '/lab'" >> /etc/jupyterhub/jupyterhub_config.py
echo "c.Authenticator.allow_all = True" >> /etc/jupyterhub/jupyterhub_config.py
```

```bash
## jupyterhub service 설정 파일 생성
    cat <<EOF > /etc/systemd/system/jupyterhub.service
[Unit]
Description=JupyterHub
After=network.target


[Service]
User=root
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=$(command -v jupyterhub) -f /etc/jupyterhub/jupyterhub_config.py

[Install]
WantedBy=multi-user.target
EOF
```

```bash
systemctl daemon-reload
systemctl enable jupyterhub.service
systemctl start jupyterhub.service
```

### ===== Raid manager 설치 진행 순서 ===== 
#### ## RAID DISK 관리 Tool인 Mega RAID Manager 를 설치 합니다. (RAID Card가 있을경우 사용 합니다.)

### # [14-1. MSM 설치](#목차)

```bash
mkdir /tmp/raid_manager
cd /tmp/raid_manager  
wget https://docs.broadcom.com/docs-and-downloads/raid-controllers/raid-controllers-common-files/17.05.00.02_Linux-64_MSM.gz
tar xzf 17.05.00.02_Linux-64_MSM.gz
cd /tmp/raid_manager/disk
apt-get -y install alien
alien --scripts *.rpm
dpkg --install lib-utils2_1.00-9_all.deb
dpkg --install megaraid-storage-manager_17.05.00-3_all.deb

systemctl daemon-reload
systemctl start vivaldiframeworkd.service
systemctl enable vivaldiframeworkd.service

cd /root
rm -rf /tmp/raid_manager
```

### # [14-2. LSA 설치](#목차)

```bash
mkdir /tmp/raid_manager
cd /tmp/raid_manager  
wget https://docs.broadcom.com/docs-and-downloads/008.012.007.000_MR7.32_LSA_Linux.zip
unzip -o 008.012.007.000_MR7.32_LSA_Linux.zip
cd webgui_rel
unzip -o LSA_Linux.zip
ls -l

cd gcc_8.3.x
yes | ./install_deb.sh -s

mkdir -p /etc/lsisash
mv /etc/init.d/LsiSASH /etc/lsisash/LsiSASH
chmod +x /etc/lsisash/LsiSASH
```
```bash
    cat <<EOF > /etc/systemd/system/lsisash.service
[Unit]
Description=Start LsiSASH service at boot
After=network.target

[Service]
Type=forking
ExecStart=/etc/lsisash/LsiSASH start
ExecStop=/etc/lsisash/LsiSASH stop
Restart=on-failure
TimeoutStopSec=30s
Restart=no

[Install]
WantedBy=multi-user.target
EOF
```

```bash

systemctl daemon-reload
systemctl enable lsisash.service
systemctl start lsisash.service
systemctl status lsisash.service

ufw allow http
ufw allow 2463/tcp
ufw reload

cd
rm -rf LSA
```

### ===== Dell 서버 전용 설치 순서 =====

### # [15. Dell 전용 OMSA설치](#목차)
#### ## Dell 서버의 경우 원격 제어를 위한 OMSA (OpenManage Server Administrator) 를 설치 합니다.

```bash
ufw allow 1311/tcp
echo 'deb http://linux.dell.com/repo/community/openmanage/10300/focal focal main' \ > /etc/apt/sources.list.d/linux.dell.com.sources.list
wget http://linux.dell.com/repo/pgp_pubkeys/0x1285491434D8786F.asc
apt-key add 0x1285491434D8786F.asc
apt-get -y update
wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb
apt-get -y install srvadmin-all

systemctl daemon-reload
systemctl enable dsm_sa_datamgrd.service
systemctl enable dsm_om_connsvc
systemctl start dsm_sa_datamgrd.service
systemctl start dsm_om_connsvc
```

***
# # END

