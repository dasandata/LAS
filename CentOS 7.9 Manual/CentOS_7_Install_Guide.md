# 다산데이타 LISR 스크립트 설치 매뉴얼 2021-12-06
다산데이타 장비 출고시 설치되는 Linux (CentOS, Ubuntu) 의 설치 표준안 입니다.  
별도의 요청사항이 없는 경우 기본적으로 아래 절차에 따라 자동 스크립트 설치가 진행 됩니다.  
이 문서는 스크립트의 수동 설치 가이드 입니다.
***

## #목차

### ===== 기본 버전 설치 진행 순서 =====

[1. 변수 선언](CentOS_7_Install_Guide.md#-1-변수-선언)

[2. rc.local 생성 및 변경](#2-rclocal-%EC%83%9D%EC%84%B1-%EB%B0%8F-%EB%B3%80%EA%B2%BD%EB%AA%A9%EC%B0%A8)  

[3. nouveau 끄기 및 grub 설정](#3-nouveau-%EB%81%84%EA%B8%B0-%EB%B0%8F-grub-%EC%84%A4%EC%A0%95%EB%AA%A9%EC%B0%A8)  

[4. selinux 제거 및 저장소 변경](#4-selinux-%EC%A0%9C%EA%B1%B0-%EB%B0%8F-%EC%A0%80%EC%9E%A5%EC%86%8C-%EB%B3%80%EA%B2%BD%EB%AA%A9%EC%B0%A8)  

[5. 기본 패키지 설치](#5-%EA%B8%B0%EB%B3%B8-%ED%8C%A8%ED%82%A4%EC%A7%80-%EC%84%A4%EC%B9%98%EB%AA%A9%EC%B0%A8)  

[6. 프로필 설정](#6-%ED%94%84%EB%A1%9C%ED%95%84-%EC%84%A4%EC%A0%95%EB%AA%A9%EC%B0%A8)  

[7. 서버 시간 동기화](#7-%EC%84%9C%EB%B2%84-%EC%8B%9C%EA%B0%84-%EB%8F%99%EA%B8%B0%ED%99%94%EB%AA%A9%EC%B0%A8)  

[8. 파이썬 설치](#8-%ED%8C%8C%EC%9D%B4%EC%8D%AC-%EC%84%A4%EC%B9%98%EB%AA%A9%EC%B0%A8)  

[9. 파이썬 패키지 설치](#9-%ED%8C%8C%EC%9D%B4%EC%8D%AC-%ED%8C%A8%ED%82%A4%EC%A7%80-%EC%84%A4%EC%B9%98%EB%AA%A9%EC%B0%A8)  

[10. 방화벽 설정](#10-%EB%B0%A9%ED%99%94%EB%B2%BD-%EC%84%A4%EC%A0%95%EB%AA%A9%EC%B0%A8)  

[11. 사용자 생성 테스트](#11-%EC%82%AC%EC%9A%A9%EC%9E%90-%EC%83%9D%EC%84%B1-%ED%85%8C%EC%8A%A4%ED%8A%B8%EB%AA%A9%EC%B0%A8)  

[12. H/W 사양 체크](#12-hw-%EC%82%AC%EC%96%91-%EC%B2%B4%ED%81%AC%EB%AA%A9%EC%B0%A8)  

### ===== GPU 버전 설치 진행 순서 ===== 

[13. CUDA,CUDNN Repo 설치](#13-cudacudnn-repo-%EC%84%A4%EC%B9%98%EB%AA%A9%EC%B0%A8)

[14. CUDA 설치 및 PATH 설정](#14-cuda-%EC%84%A4%EC%B9%98-%EB%B0%8F-path-%EC%84%A4%EC%A0%95%EB%AA%A9%EC%B0%A8)

[15. CUDNN 설치 및 PATH 설정](#15-cudnn-%EC%84%A4%EC%B9%98-%EB%B0%8F-path-%EC%84%A4%EC%A0%95%EB%AA%A9%EC%B0%A8)

[16. 딥러닝 패키지 설치](#16-%EB%94%A5%EB%9F%AC%EB%8B%9D-%ED%8C%A8%ED%82%A4%EC%A7%80-%EC%84%A4%EC%B9%98%EB%AA%A9%EC%B0%A8)

### ===== 서버 전용 설치 진행 순서 ===== 

[17. 서버 전용 MSM 설치](#17-%EC%84%9C%EB%B2%84-%EC%A0%84%EC%9A%A9-msm-%EC%84%A4%EC%B9%98%EB%AA%A9%EC%B0%A8)

### ===== Dell 서버 전용 설치 순서 =====

[18. Dell 전용 OMSA설치](#18-dell-%EC%A0%84%EC%9A%A9-omsa%EC%84%A4%EC%B9%98%EB%AA%A9%EC%B0%A8)

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
VENDOR=$(dmidecode | grep -i manufacturer | awk '{print$2}' | head -1)

# 지금 작동중인 네트워크 인터페이스 명을 확인 후 NIC 변수로 적용합니다.
NIC=$(ip a | grep 'state UP' | cut -d ":" -f 2 | tr -d ' ')

# 현재 설치된 OS의 종류를 확인 합니다. (ex: centos, ubuntu)
OSCHECK=$(cat /etc/os-release | head -1 | cut -d "=" -f 2 | tr -d "\"" | awk '{print$1}' | tr '[A-Z]' '[a-z]')

# centos의 정확한 버전을 확인 합니다.
OS=$(cat /etc/redhat-release | awk '{print$1,$4}' | cut -d "." -f 1 | tr -d " " | tr '[A-Z]' '[a-z]')

# ubuntu의 정확한 버전을 확인 합니다.
OS=$(lsb_release -isr |  tr -d "." | sed -e '{N;s/\n//}' | tr '[A-Z]' '[a-z]')

# CUDA 설치 버전을 중 선택하여 CUDAV라는 변수로 사용합니다.
select CUDAV in 10-0 10-1 10-2 11-0 11-1 No-GPU; do echo "Select CUDA Version : $CUDAV" ; break; done
```

### # [2. rc.local 생성 및 변경](#목차) 
#### ## 여기서는 사용하지 않습니다.

 === CentOS 7.9 ===
```bash
# rc.local에 파일명을 입력하여 재부팅 후에도 다시 실행될 수 있게 변경 합니다.
chmod +x /etc/rc.d/rc.local
sed -i '12a bash /root/LAS/Linux_Auto_Script.sh' /etc/rc.d/rc.local
```

 === Ubuntu 20.04 ===
```bash
# rc.local에 파일명을 입력하여 재부팅 후에도 다시 실행될 수 있게 변경 합니다.
chmod +x /etc/rc.local
systemctl restart rc-local.service
systemctl status rc-local.service
sed -i '1a bash /root/LAS/Linux_Auto_Script.sh' /etc/rc.local
```

### # [3. nouveau 끄기 및 grub 설정](#목차)
#### ## 부팅시 화면에 부팅 기록 출력, IPv6 비활성화, nouveau 비활성화를 위해 진행 합니다.
 === CentOS 7.9 ===
```bash
NIC=$(ip a | grep 'state UP' | cut -d ":" -f 2 | tr -d ' ')
# 부팅시 화면에 부팅 기록을 출력 및 IPv6 비활성화를 위해 설정 변경.
sed -i  's/rhgb//'   /etc/default/grub
sed -i  's/quiet//'  /etc/default/grub
sed -i  's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="ipv6.disable=1 /' /etc/default/grub
sed -i  '/IPV6/d' /etc/sysconfig/network-scripts/ifcfg-${NIC}

# Nvidia Driver 설치시 nouveau 제거
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "options nouveau modeset=0" >> /etc/modprobe.d/blacklist.conf

# 변경된 내용으로 initramfs 및 grub 재설정
dracut  -f
grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
```

 === Ubuntu 20.04 ===
```bash
# 부팅시 화면에 부팅 기록을 출력 및 IPv6 비활성화를 위해 설정 변경.
perl -pi -e 's/splash//' /etc/default/grub
perl -pi -e 's/quiet//'  /etc/default/grub
perl -pi -e  's/^GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="ipv6.disable=1 /'  /etc/default/grub
perl -pi -e  's/^GRUB_HIDDEN_TIMEOUT=/#GRUB_HIDDEN_TIMEOUT=/'  /etc/default/grub

# Nvidia와 호환이 좋지 않은 누보 제거 
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "options nouveau modeset=0" >> /etc/modprobe.d/blacklist.conf

# 변경된 내용으로 initramfs 및 grub 재설정
update-initramfs -u && update-grub2
```

### # [4. selinux 제거 및 저장소 변경](#목차)
#### ## CentOS는 설정이 복잡한 SELINUX를 disable 합니다.
#### ## Ubuntu는 기존 저장소 속도 최적화를 위해 변경 합니다.
 === CentOS 7.9 ===
```bash
# 기존의 SELINUX 상태 확인 후 disable로 변경 (재부팅 후 적용 됩니다.)
getenforce

# 변경 전 : enforcing / 변경 후 : disabled
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# 적용되었는지 확인
cat /etc/selinux/config | grep "SELINUX=disabled"
```

 === Ubuntu 20.04 ===
```bash
# 기존 저장소 주소보다 빠른 mirror.kakao.com 으로 변경
perl -pi -e 's/kr.archive.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list
perl -pi -e 's/security.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list
cat /etc/apt/sources.list | grep -v "#\|^$"
```

### # [5. 기본 패키지 설치](#목차)
#### ## 서버 기본 설정에 필요한 패키지를 설치 합니다.
#### ## 필요없는 서비스를 disable 합니다 (장비에 따라 존재하지 않는 서비스도 있습니다.)
 === CentOS 7.9 ===
```bash
yum -y update
yum install -y epel-release
yum install -y ethtool pciutils openssh mlocate nfs-utils rdate xauth firefox nautilus wget bind-utils
yum install -y tcsh tree lshw tmux git kernel-headers kernel-devel gcc make gcc-c++ snapd yum-utils
yum install -y cmake python-devel ntfs-3g dstat perl perl-CPAN perl-core net-tools openssl-devel git-lfs vim
yum -y groups install "Development Tools"
yum install -y glibc-static glibc-devel libstdc++ libstdc++-devel
sed -i -e "s/\]$/\]\npriority=5/g" /etc/yum.repos.d/epel.repo
yum install -y yum-plugin-priorities
yum install -y htop ntfs-3g figlet smartmontools

#불필요한 서비스 disable
systemctl disable bluetooth.service
systemctl disable iscsi.service
systemctl disable ksm.service
systemctl disable ksmtuned.service
systemctl disable libstoragemgmt.service
systemctl disable libvirtd.service
systemctl disable NetworkManager.service
systemctl stop    NetworkManager.service
systemctl disable NetworkManager-dispatcher.service
systemctl disable NetworkManager-wait-online.service
systemctl disable spice-vdagentd.service
systemctl disable vmtoolsd.service
systemctl disable ModemManager.service
systemctl disable cups.service
systemctl disable cups-browsed.service

## IPMI가 있는 서버의 경우 ipmitool을 설치 합니다.
# yum install -y ipmitool
```

 === Ubuntu 20.04 ===
```bash
apt-get update
apt-get -y install vim nfs-common rdate xauth firefox gcc make tmux wget figlet net-tools
apt-get -y install xfsprogs ntfs-3g aptitude lvm2 dstat curl npm python mlocate ubuntu-desktop
apt-get -y install dconf-editor gnome-panel gnome-settings-daemon metacity nautilus gnome-terminal
apt-get -y install libzmq3-dev libcurl4-openssl-dev libxml2-dev snapd ethtool htop dnsutils
DEBIAN_FRONTEND=noninteractive apt-get install -y smartmontools

# 불필요한 서비스 disable
systemctl disable bluetooth.service
systemctl disable iscsi.service
systemctl disable ksm.service
systemctl disable ksmtuned.service
systemctl disable libstoragemgmt.service
systemctl disable libvirtd.service
systemctl disable spice-vdagentd.service
systemctl disable vmtoolsd.service
systemctl disable ModemManager.service
systemctl disable cups.service
systemctl disable cups-browsed.service

# Ubuntu Desktop (GUI) 환경을 사용할 경우 disable 하지 않습니다.
systemctl disable NetworkManager.service
systemctl stop    NetworkManager.service

# IPMI가 있는 장치의 경우 ipmitool을 설치 합니다.
# apt-get install -y ipmitool
```

### # [6. 프로필 설정](#목차)
#### ## 사용자 편의를 위한 설정을 진행 합니다.
#### ## alias, prompt-color, History Size, History date
 === CentOS 7.9, Ubuntu20.04 ===
```bash
# alias 설정
echo " "                                >>  /etc/profile
echo "# Add by Dasandata"               >>  /etc/profile
echo "alias vi='vim' "                  >>  /etc/profile
echo "alias ls='ls --color=auto' "      >>  /etc/profile
echo "alias ll='ls -lh' "               >>  /etc/profile
echo "alias grep='grep --color=auto' "  >>  /etc/profile
echo " "                                >>  /etc/profile

# History 시간표시 및 프롬프트 색상 변경
echo "# Add Timestamp to .bash_history "                    >>  /etc/profile
echo 'export HISTTIMEFORMAT="20%y/%m/%d %T "'               >>  /etc/profile
echo "export PS1='\[\e[1;46;30m\][\u@\h:\W]\\$\[\e[m\] '"   >>  /root/.bashrc
echo "export PS1='\[\e[1;47;30m\][\u@\h:\W]\\$\[\e[m\] '"   >>  /home/sonic/.bashrc

# 변경사항 적용 및 불러오기
source  /etc/profile
source  /root/.bashrc
echo $HISTSIZE
```

### # [7. 서버 시간 동기화](#목차)
#### ## 서버 및 HW 시간을 동기화 합니다.
 === CentOS 7.9, Ubuntu 20.04===
```bash
# time.bora.net 기준으로 시간 동기화
rdate -s time.bora.net
hwclock --systohc

# 현재 시간과 동일한지 확인
date
hwclock
```

### # [8. 파이썬 설치](#목차)
 === CentOS 7.9 ===
```bash
# Python 2.7 , 3.6 버전 설치
yum -y install python-devel python-setuptools python-setuptools-devel
curl -O https://bootstrap.pypa.io/pip/2.7/get-pip.py
python get-pip.py
yum -y install python36  python36-devel python36-pip python36-setuptools
easy_install-3.6   pip
yum -y install openblas*
pip   install --upgrade pip
pip3  install --upgrade pip
perl -pi -e 's/python3/python/'   /usr/local/bin/pip
```

 === Ubuntu 20.04 ===
```bash
# Python 2.7 , 3.6 버전 설치
apt-get -y install python3-pip
add-apt-repository universeapt update
apt update
apt list --upgradeable
apt install -y python2
curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py
python2.7 get-pip.py --force-reinstall
pip3 install --upgrade pip
perl -pi -e 's/python3/python/'   /usr/local/bin/pip
```

### # [9. 파이썬 패키지 설치](#목차)
 === CentOS 7.9 ===
```bash
# Python 2.7 , 3.6에 사용할 패키지 설치
# Python 2.7 의 경우 지원이 종료된다는 경고 문구가 표시됩니다.
pip install numpy  scipy  nose  matplotlib  pandas  keras
yum erase -y python-ldap pyparsing
pip3 install  numpy   scipy  nose  matplotlib  pandas  keras
rm -rf /usr/share/doc/python-enum34-1.0.4*
rm -rf /usr/lib/python2.7/site-packages/enum34-1.0.4-py2.7.egg-info
## python2.7에서 setuptools 지원 종료로 인해 44 버전까지 지원 (torch 설치는 40 버전에서 가능)
## tensorflow-gpu 1.13.1 설치시 grpcio 설치에 필요한 setuptools 버전이 49 이상이 필요로 설치 불가
#pip install   --upgrade tensorflow-gpu==1.13.1
pip install   --upgrade setuptools==40
pip3 install  --upgrade setuptools
pip3 install  --upgrade tensorflow-gpu==1.13.1
pip install   torch torchvision
pip3 install  torch torchvision
pip3 install  --upgrade optimuspyspark
```

 === Ubuntu 20.04 ===
```bash
# Python 2.7 , 3.6에 사용할 패키지 설치
# Python 2.7 의 경우 지원이 종료된다는 경고 문구가 표시됩니다.
pip install --upgrade numpy scipy  nose  matplotlib  pandas  keras tensorflow-gpu
pip install scipy==1.2.2
pip3 install --upgrade numpy scipy nose matplotlib pandas keras tensorflow-gpu
pip3 install numpy==1.16.0 h5py==2.10.0 cryptography==3.3.2
pip install --upgrade torch torchvision 
pip3 install --upgrade torch torchvision
```

### # [10. 방화벽 설정](#목차)
 === CentOS 7.9 ===
```bash
# 기존 방화벽 Zone 변경 후 패키지 및 ssh 포트 변경 작업 진행
firewall-cmd --get-zones
firewall-cmd --list-all
firewall-cmd --get-default-zone
firewall-cmd --change-interface=${NIC} --zone=external --permanent
firewall-cmd --set-default-zone=external
firewall-cmd --reload
# ssh 변경될 포트 추가
firewall-cmd --add-port=7777/tcp --zone=external --permanent

## R Server Port
firewall-cmd --add-port=8787/tcp --zone=external --permanent

## jupyterHub Port
firewall-cmd --add-port=8000/tcp --zone=external --permanent
firewall-cmd --remove-service=ssh --zone=external --permanent
firewall-cmd --reload

# ssh 기존 22 포트에서 7777로 변경
sed -i  "s/#Port 22/Port 7777/g" /etc/ssh/sshd_config
sed -i  "s/#PermitRootLogin yes/PermitRootLogin no/g" /etc/ssh/sshd_config
echo "AddressFamily inet" >> /etc/ssh/sshd_config
systemctl restart sshd
```

 === Ubuntu 20.04 ===
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

perl -pi -e "s/#Port 22/Port 7777/g" /etc/ssh/sshd_config
perl -pi -e "s/PermitRootLogin prohibit-password/PermitRootLogin no/g" /etc/ssh/sshd_config
echo "AddressFamily inet" >> /etc/ssh/sshd_config
systemctl restart sshd
```

### # [11. 사용자 생성 테스트](#목차)
 === CentOS 7.9 ===
```bash
#다산 계정 생성 테스트 진행
useradd dasan
usermod -aG wheel dasan
```

 === Ubuntu 20.04 ===
```bash
adduser --disabled-login --gecos "" dasan
usermod -G sudo dasan
```

### # [12. H/W 사양 체크](#목차)
 === CentOS 7.9, Ubuntu 20.04 ===
```bash
# 기본적인 시스템 사양 체크를 진행합니다.
dmidecode --type system | grep -v "^$\|#\|SMBIOS\|Handle\|Not"
lscpu | grep -v "Flags\|NUMA"
dmidecode --type 16 | grep -v "dmidecode\|SMBIOS\|Handle"
dmidecode --type memory | grep "Number Of Devices\|Size\|Locator\|Clock\|DDR\|Rank" | grep -v "No\|Unknown"
cat /proc/meminfo | grep MemTotal
free -h
lspci | grep -i vga
lspci | grep -i nvidia
dmidecode | grep NIC
lspci | grep -i communication
dmesg | grep NIC
dmidecode --type 39  | grep "System\|Name:\|Capacity"
blkid
uname -a
```
***
<br/>

## ## 아래 부분을 진행 하기 전에 위 사항들이 적용 될 수 있게 재부팅을 진행 합니다.
 === CentOS 7.9, Ubuntu 20.04 ===
```bash
reboot
```
<br/>

***

### ===== GPU 버전 설치 진행 순서 ===== 
#### ### 아래 13 ~ 16 항목의 경우 Nvidia-GPU가 존재할 경우 진행 합니다.

### # [13. CUDA,CUDNN Repo 설치](#목차)
 === CentOS 7.9 ===
```bash
# 사용할 CUDA 버전을 선택합니다.
select CUDAV in 10-0 10-1 10-2 11-0 11-1 11-2 11-3 11-4 11-5; do echo "Select CUDA Version : $CUDAV" ; break; done

# Nvidia 저장소 생성 (Cuda,cudnn 설치를 위해)
yum-config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/cuda-rhel7.repo
wget https://developer.download.nvidia.com/compute/machine-learning/repos/rhel7/x86_64/nvidia-machine-learning-repo-rhel7-1.0.0-1.x86_64.rpm
yum -y install nvidia-machine-learning-repo-rhel7-1.0.0-1.x86_64.rpm

# nvidia X11 관련 lib 설치
yum --disablerepo="*" --enablerepo="cuda" list available
yum -y install libXi-devel mesa-libGLU-devel libXmu-devel libX11-devel freeglut-devel libXm*
yum -y install openmotif*
```

 === Ubuntu 20.04 ===
```bash
# 사용할 CUDA 버전을 선택합니다.
select CUDAV in 11-0 11-1 11-2 11-3 11-4 11-5; do echo "Select CUDA Version : $CUDAV" ; break; done

# 자세한 Ubuntu 버전을 변수로 선언합니다.
OS=$(lsb_release -isr |  tr -d "." | sed -e '{N;s/\n//}' | tr '[A-Z]' '[a-z]')

# Nvidia 저장소 생성 (Cuda,cudnn 설치를 위해)
apt-get -y install sudo gnupg
apt-key adv --fetch-keys "https://developer.download.nvidia.com/compute/cuda/repos/"$OS"/x86_64/7fa2af80.pub"
sh -c 'echo "deb https://developer.download.nvidia.com/compute/cuda/repos/'$OS'/x86_64 /" > /etc/apt/sources.list.d/nvidia-cuda.list'
sh -c 'echo "deb https://developer.download.nvidia.com/compute/machine-learning/repos/'$OS'/x86_64 /" > /etc/apt/sources.list.d/nvidia-machine-learning.list' 
apt-get update
```

### # [14. CUDA 설치 및 PATH 설정](#목차)
 === CentOS 7.9 ===
```bash
# CUDA 설치
yum -y install cuda-$CUDAV

# profile에 PATH 설정시에는 cuda-11-1의 형식이 아닌 cuda-11.1 같은 형식으로 변경되어야 합니다.
CUDAV="${CUDAV/-/.}"

# cuda 설치 및 설치된 cuda를 사용하기 위해 경로 설정값을 profile에 입력
echo " "  >> /etc/profile
echo "### ADD Cuda $CUDAV PATH"  >> /etc/profile
echo "export PATH=/usr/local/cuda-$CUDAV/bin:/usr/local/cuda-$CUDAV/include:\$PATH " >> /etc/profile
echo "export LD_LIBRARY_PATH=/usr/local/cuda-$CUDAV/lib64:/usr/local/cuda/extras/CUPTI/:\$LD_LIBRARY_PATH " >> /etc/profile
echo "export CUDA_HOME=/usr/local/cuda-$CUDAV " >> /etc/profile
echo "export CUDA_INC_DIR=/usr/local/cuda-$CUDAV/include " >> /etc/profile

# 지속성 모드 On, 변경된 PATH 적용
systemctl enable nvidia-persistenced
source /etc/profile
source /root/.bashrc
```

 === Ubuntu 20.04 ===
```bash
# CUDA 설치
apt-get -y install cuda-$CUDAV

# profile에 PATH 설정시에는 cuda-11-1의 형식이 아닌 cuda-11.1 같은 형식으로 변경되어야 합니다.
CUDAV="${CUDAV/-/.}"

# cuda 설치 및 설치된 cuda를 사용하기 위해 경로 설정값을 profile에 입력
echo " "  >> /etc/profile
echo "### ADD Cuda $CUDAV PATH"  >> /etc/profile
echo "export PATH=/usr/local/cuda-$CUDAV/bin:/usr/local/cuda-$CUDAV/include:\$PATH " >> /etc/profile
echo "export LD_LIBRARY_PATH=/usr/local/cuda-$CUDAV/lib64:/usr/local/cuda/extras/CUPTI/:\$LD_LIBRARY_PATH " >> /etc/profile
echo "export CUDA_HOME=/usr/local/cuda-$CUDAV " >> /etc/profile
echo "export CUDA_INC_DIR=/usr/local/cuda-$CUDAV/include " >> /etc/profile

# 지속성 모드 On, 변경된 PATH 적용
systemctl enable nvidia-persistenced
source /etc/profile
source /root/.bashrc
```

### # [15. CUDNN 설치 및 PATH 설정](#목차)
 === CentOS 7.9 ===
```bash
# CUDA 10 버전
yum -y install libcudnn7*

# CUDA 11 버전
yum -y install libcudnn8*
```

 === Ubuntu 20.04 ===
```bash
# Ubuntu 20.04 는 CUDA 11 버전부터 지원하여 libcudnn8 버전만 설치 가능
apt-get -y install libcudnn8*
```

### # [16. 딥러닝 패키지 설치](#목차)
#### ## JupyterHub는 마지막 설정이 동일하여 마지막에 같이 서술하였습니다.
#### ## 마지막 설정에 사용되는 파일은 Git에 LAS 밑에 존재합니다.
 === CentOS 7.9 ===
```bash
# 딥러닝 패키지 (R, R-Server, JupyterHub) 를 설치 합니다.
# JupyterHub에 작업 중 사용되는 파일들은 LAS에 존재하므로 git을 통해 Pull 하고 사용해야 합니다.
## R,R-sutdio install
yum -y install R 
wget https://download2.rstudio.org/server/centos7/x86_64/rstudio-server-rhel-2022.02.0-443-x86_64.rpm  
yum -y install rstudio-server-rhel-2022.02.0-443-x86_64.rpm 

## JupyterHub install
pip3 install --upgrade jupyterhub jupyterlab notebook 
wget https://rpm.nodesource.com/pub_16.x/el/7/x86_64/nodejs-16.10.0-1nodesource.x86_64.rpm 
wget https://rpm.nodesource.com/pub_16.x/el/7/x86_64/nodejs-devel-16.10.0-1nodesource.x86_64.rpm 
rpm -ivh nodejs-16.10.0-1nodesource.x86_64.rpm nodejs-devel-16.10.0-1nodesource.x86_64.rpm 
npm install -g configurable-http-proxy 
```

 === Ubuntu 20.04 ===
```bash
# 딥러닝 패키지 (R, R-Server, JupyterHub) 를 설치 합니다.
# JupyterHub에 작업 중 사용되는 파일들은 LISR에 존재하므로 git을 통해 Pull 하고 사용해야 합니다.

## R,R-studio install
apt-get -y install r-base 
apt-get -y install gdebi-core 
wget https://download2.rstudio.org/server/bionic/amd64/rstudio-server-2022.02.0-443-amd64.deb 
yes | gdebi rstudio-server-2022.02.0-443-amd64.deb 

## JupyterHub install
pip3 install --upgrade jupyterhub jupyterlab notebook 
curl -fsSL https://deb.nodesource.com/setup_16.x | bash - 
apt-get -y install nodejs default-jre 
npm install -g configurable-http-proxy 

## Pycharm install
snap install pycharm-community --classic
```

 === CentOS 7.9, Ubuntu 20.04 ===
```bash
## CentOS , Ubuntu 동일하게 JupyterHub 마무리 작업을 진행 합니다.
mkdir /etc/jupyterhub
jupyterhub --generate-config -f /etc/jupyterhub/jupyterhub_config.py 
sed -i '356a c.JupyterHub.port = 8000' /etc/jupyterhub/jupyterhub_config.py
sed -i '358a c.LocalAuthenticator.create_system_users = True' /etc/jupyterhub/jupyterhub_config.py
sed -i '359a c.Authenticator.add_user_cmd = ['adduser', '--force-badname', '-q', '--gecos', '""', '--disabled-password']' /etc/jupyterhub/jupyterhub_config.py
sed -i '384a c.JupyterHub.proxy_class = 'jupyterhub.proxy.ConfigurableHTTPProxy'' /etc/jupyterhub/jupyterhub_config.py
sed -i '824a c.Authenticator.admin_users = {"sonic"}' /etc/jupyterhub/jupyterhub_config.py
sed -i '929a c.Spawner.default_url = '/lab'' /etc/jupyterhub/jupyterhub_config.py

## jupyterhub service 설정 파일 복사
mv /root/LAS/jupyterhub.service /lib/systemd/system/
mv /root/LAS/jupyterhub /etc/init.d/
chmod 777 /lib/systemd/system/jupyterhub.service 
chmod 755 /etc/init.d/jupyterhub 
systemctl daemon-reload 
systemctl enable jupyterhub.service 
systemctl restart jupyterhub.service 
R CMD BATCH /root/LAS/r_jupyterhub.R 
```

### ===== 서버 전용 설치 진행 순서 ===== 

### # [17. 서버 전용 MSM 설치](#목차)
#### ## RAID DISK 관리 Tool인 Mega RAID Manager 를 설치 합니다. (RAID Card가 있을경우 사용 합니다.)
 === CentOS 7.9 ===
```bash
mkdir /tmp/raid_manager
cd /tmp/raid_manager
wget https://docs.broadcom.com/docs-and-downloads/raid-controllers/raid-controllers-common-files/17.05.00.02_Linux-64_MSM.gz
tar xvzf 17.05.00.02_Linux-64_MSM.gz
cd /tmp/raid_manager/disk/ && ./install.csh -a
systemctl daemon-reload
systemctl start vivaldiframeworkd.service
systemctl enable vivaldiframeworkd.service
/usr/local/MegaRAID\ Storage\ Manager/startupui.sh &
cd
```

 === Ubuntu 20.04 ===
```bash
mkdir /tmp/raid_manager
cd /tmp/raid_manager
wget https://docs.broadcom.com/docs-and-downloads/raid-controllers/raid-controllers-common-files/17.05.00.02_Linux-64_MSM.gz
tar xvzf 17.05.00.02_Linux-64_MSM.gz
cd /tmp/raid_manager/disk
apt-get -y install alien
alien --scripts *.rpm
dpkg --install lib-utils2_1.00-9_all.deb
dpkg --install megaraid-storage-manager_17.05.00-3_all.deb
systemctl daemon-reload
systemctl start vivaldiframeworkd.service
systemctl enable vivaldiframeworkd.service
/usr/local/MegaRAID\ Storage\ Manager/startupui.sh &
cd
```

### ===== Dell 서버 전용 설치 순서 =====

### # [18. Dell 전용 OMSA설치](#목차)
#### ## Dell 서버의 경우 원격 제어를 위한 OMSA (OpenManage Server Administrator) 를 설치 합니다.
 === CentOS 7.9 ===
```bash
perl -p -i -e '$.==20 and print "exclude = libsmbios smbios-utils-bin\n"' /etc/yum.repos.d/CentOS-Base.repo
wget http://linux.dell.com/repo/hardware/dsu/bootstrap.cgi -O  ./dellomsainstall.sh
sed -i -e "s/enabled=1/enabled=0/g" ./dellomsainstall.sh 
bash ./dellomsainstall.sh
rm -f ./dellomsainstall.sh
yum -y erase  tog-pegasus-libs
yum -y install --enablerepo=dell-system-update_dependent -y srvadmin-all openssl-devel
systemctl enable dataeng
systemctl enable dsm_om_connsvc
systemctl start dataeng
systemctl start dsm_om_connsvc
```

 === Ubuntu 20.04 ===
```bash
ufw allow 1311/tcp
echo 'deb http://linux.dell.com/repo/community/openmanage/950/focal focal main'  > /etc/apt/sources.list.d/linux.dell.com.sources.list
wget http://linux.dell.com/repo/pgp_pubkeys/0x1285491434D8786F.asc
apt-key add 0x1285491434D8786F.asc
apt-get -y update
apt-get -y install srvadmin-all
cd /usr/lib/x86_64-linux-gnu/
ln -s /usr/lib/x86_64-linux-gnu/libssl.so.1.1 libssl.so
cd
systemctl enable dsm_sa_datamgrd.service
systemctl enable dsm_om_connsvc
systemctl start dsm_sa_datamgrd.service
systemctl start dsm_om_connsvc
```

***
# # END
