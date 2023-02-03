# 다산데이타 LISR 스크립트 설치 매뉴얼 2022-03-25
다산데이타 장비 출고시 설치되는 CentOS 7.9 설치 표준안 입니다.  
별도의 요청사항이 없는 경우 기본적으로 아래 절차에 따라 자동 스크립트 설치가 진행 됩니다.  
이 문서는 스크립트의 수동 설치 가이드 입니다.
***

## #목차

### ===== 기본 버전 설치 진행 순서 =====

[1. 변수 선언](CentOS_7_Install_Guide.md#-1-변수-선언)  

[2. rc.local 생성 및 변경](CentOS_7_Install_Guide.md#-2-rclocal-생성-및-변경)  

[3. nouveau 끄기 및 grub 설정](CentOS_7_Install_Guide.md#-3-nouveau-끄기-및-grub-설정)  

[4. selinux 제거](CentOS_7_Install_Guide.md#-4-selinux-제거)  

[5. 기본 패키지 설치](CentOS_7_Install_Guide.md#-5-기본-패키지-설치)  

[6. 프로필 설정](CentOS_7_Install_Guide.md#-6-프로필-설정)  

[7. 서버 시간 동기화](CentOS_7_Install_Guide.md#-7-서버-시간-동기화)  

[8. 파이썬 설치](CentOS_7_Install_Guide.md#-8-파이썬-설치)  

[9. 파이썬 패키지 설치](CentOS_7_Install_Guide.md#-9-파이썬-패키지-설치)  

[10. 방화벽 설정](CentOS_7_Install_Guide.md#-10-방화벽-설정)  

[11. 사용자 생성 테스트](CentOS_7_Install_Guide.md#-11-사용자-생성-테스트)  

[12. H/W 사양 체크](CentOS_7_Install_Guide.md#-12-HW-사양-체크)  

### ===== GPU 버전 설치 진행 순서 ===== 

[13. CUDA,CUDNN Repo 설치](CentOS_7_Install_Guide.md#-13-CUDACUDNN-Repo-설치)

[14. CUDA 설치 및 PATH 설정](CentOS_7_Install_Guide.md#-14-CUDA-설치-및-PATH-설정)

[15. CUDNN 설치](CentOS_7_Install_Guide.md#-15-CUDNN-설치)

[16. 딥러닝 패키지 설치](CentOS_7_Install_Guide.md#-16-딥러닝-패키지-설치)

### ===== 서버 전용 설치 진행 순서 ===== 

[17. 서버 전용 MSM 설치](CentOS_7_Install_Guide.md#-17-서버-전용-MSM-설치)

### ===== Dell 서버 전용 설치 순서 =====

[18. Dell 전용 OMSA설치](CentOS_7_Install_Guide.md#-18-Dell-전용-OMSA설치)

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

# 현재 설치된 OS의 종류를 확인 합니다. (ex: centos, ubuntu, rocky)
OSCHECK=$(cat /etc/os-release | head -1 | cut -d "=" -f 2 | tr -d "\"" | awk '{print$1}' | tr '[A-Z]' '[a-z]')

# centos의 정확한 버전을 확인 합니다.
OS=$(cat /etc/redhat-release | awk '{print$1,$4}' | cut -d "." -f 1 | tr -d " " | tr '[A-Z]' '[a-z]')

# CUDA 설치 버전을 중 선택하여 CUDAV라는 변수로 사용합니다.
select CUDAV in 10-0 10-1 10-2 11-0 11-1 11-2 11-3 No-GPU; do echo "Select CUDA Version : $CUDAV" ; break; done
```

### # [2. rc.local 생성 및 변경](#목차) 
#### ## 여기서는 사용하지 않습니다.


```bash
# rc.local에 파일명을 입력하여 재부팅 후에도 다시 실행될 수 있게 변경 합니다.
chmod +x /etc/rc.d/rc.local
sed -i '13a systemctl restart rc-local.service' /etc/rc.d/rc.local
sed -i '14a bash /root/LAS/Linux_Auto_Script.sh' /etc/rc.d/rc.local
```

### # [3. nouveau 끄기 및 grub 설정](#목차)
#### ## 부팅시 화면에 부팅 기록 출력, IPv6 비활성화, nouveau 비활성화를 위해 진행 합니다.

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

### # [4. selinux 제거](#목차)
#### ## CentOS는 설정이 복잡한 SELINUX를 disable 합니다.

```bash
# 기존의 SELINUX 상태 확인 후 disable로 변경 (재부팅 후 적용 됩니다.)
getenforce

# 변경 전 : enforcing / 변경 후 : disabled
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# 적용되었는지 확인
cat /etc/selinux/config | grep "SELINUX=disabled"
```

### # [5. 기본 패키지 설치](#목차)
#### ## 서버 기본 설정에 필요한 패키지를 설치 합니다.
#### ## 필요없는 서비스를 disable 합니다 (장비에 따라 존재하지 않는 서비스도 있습니다.)

```bash
yum -y update
yum install -y epel-release
yum install -y ethtool pciutils openssh mlocate nfs-utils rdate xauth firefox nautilus wget bind-utils
yum install -y tcsh tree lshw tmux git kernel-headers kernel-devel gcc make gcc-c++ snapd yum-utils
yum install -y cmake ntfs-3g dstat perl perl-CPAN perl-core net-tools openssl-devel git-lfs vim

# GUI 관련 Tool 설치
yum -y groupinstall "GNOME Desktop" 
yum -y groupinstall "Graphical Administration Tools" 
yum install -y glibc-static yum-plugin-priorities 
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

### # [6. 프로필 설정](#목차)
#### ## 사용자 편의를 위한 설정을 진행 합니다.
#### ## alias, prompt-color, History Size, History date

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

```bash
# time.bora.net 기준으로 시간 동기화
rdate -s time.bora.net
hwclock --systohc

# 현재 시간과 동일한지 확인
date
hwclock
```

### # [8. 파이썬 설치](#목차)

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

### # [9. 파이썬 패키지 설치](#목차)

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

### # [10. 방화벽 설정](#목차)

```bash
# 방화벽 실행
systemctl enable firewalld 
systemctl restart firewalld 
# ssh 포트 변경
firewall-cmd --add-port=7777/tcp  --permanent 
## R Server Port 개방
firewall-cmd --add-port=8787/tcp  --permanent 
## jupyterHub Port 개방
firewall-cmd --add-port=8000/tcp  --permanent 
## masquerade on
firewall-cmd --add-masquerade --permanent 
## remove service
firewall-cmd --zone=public --remove-service=dhcpv6-client  --permanent 
firewall-cmd --zone=public --remove-service=ssh  --permanent 
firewall-cmd --reload 
# ssh 기존 22 포트에서 7777로 변경
sed -i  "s/#Port 22/Port 7777/g" /etc/ssh/sshd_config
sed -i  "s/#PermitRootLogin yes/PermitRootLogin no/g" /etc/ssh/sshd_config
echo "AddressFamily inet" >> /etc/ssh/sshd_config
systemctl restart sshd
```

### # [11. 사용자 생성 테스트](#목차)

```bash
#다산 계정 생성 테스트 진행
useradd dasan
usermod -aG wheel dasan
```

### # [12. H/W 사양 체크](#목차)

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

```bash
reboot
```
<br/>

***

### ===== GPU 버전 설치 진행 순서 ===== 
#### ### 아래 13 ~ 16 항목의 경우 Nvidia-GPU가 존재할 경우 진행 합니다.

### # [13. CUDA,CUDNN Repo 설치](#목차)

```bash
# 사용할 CUDA 버전을 선택합니다.
select CUDAV in 10-0 10-1 10-2 11-0 11-1 11-2 11-3; do echo "Select CUDA Version : $CUDAV" ; break; done

# Nvidia 저장소 생성 (Cuda,cudnn 설치를 위해)
yum-config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/cuda-rhel7.repo
wget https://developer.download.nvidia.com/compute/machine-learning/repos/rhel7/x86_64/nvidia-machine-learning-repo-rhel7-1.0.0-1.x86_64.rpm
yum -y install nvidia-machine-learning-repo-rhel7-1.0.0-1.x86_64.rpm

# nvidia X11 관련 lib 설치
yum --disablerepo="*" --enablerepo="cuda-rhel7-x86_64" list available
yum -y install libXi-devel mesa-libGLU-devel libXmu-devel libX11-devel freeglut-devel libXm*
yum -y install openmotif*
```

### # [14. CUDA 설치 및 PATH 설정](#목차)

```bash
# CUDA 설치

rpm --import http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/D42D0685.pub
yum -y install kmod-nvidia-latest-dkms

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

### # [15. CUDNN 설치](#목차)

```bash
# CUDA 10 버전
yum -y install libcudnn7*

# CUDA 11 버전
yum -y install libcudnn8*
```

### # [16. 딥러닝 패키지 설치](#목차)
#### ## JupyterHub는 마지막 설정이 동일하여 마지막에 같이 서술하였습니다.
#### ## 마지막 설정에 사용되는 파일은 Git에 LAS 밑에 존재합니다.

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


```bash
mkdir /etc/jupyterhub
jupyterhub --generate-config -f /etc/jupyterhub/jupyterhub_config.py 
sed -i '356a c.JupyterHub.port = 8000' /etc/jupyterhub/jupyterhub_config.py
sed -i '358a c.LocalAuthenticator.create_system_users = True' /etc/jupyterhub/jupyterhub_config.py
sed -i '359a c.Authenticator.add_user_cmd = ['adduser', '--force-badname', '-q', '--gecos', '""', '--disabled-password']' /etc/jupyterhub/jupyterhub_config.py
sed -i '384a c.JupyterHub.proxy_class = 'jupyterhub.proxy.ConfigurableHTTPProxy'' /etc/jupyterhub/jupyterhub_config.py
sed -i '824a c.Authenticator.admin_users = {"sonic"}' /etc/jupyterhub/jupyterhub_config.py
sed -i '929a c.Spawner.default_url = '/lab'' /etc/jupyterhub/jupyterhub_config.py

## jupyterhub service 설정 파일 복사에 필요한 파일 가져오기
git clone https://github.com/dasandata/LAS
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

### ===== Dell 서버 전용 설치 순서 =====

### # [18. Dell 전용 OMSA설치](#목차)
#### ## Dell 서버의 경우 원격 제어를 위한 OMSA (OpenManage Server Administrator) 를 설치 합니다.

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

***
# # END
