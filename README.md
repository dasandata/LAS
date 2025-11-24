# 안녕하세요 다산데이타 입니다.  
다산데이타 에서 출고되는 서버 & 워크스테이션에 설치되는 리눅스 표준설치 메뉴얼 과 스크립트 입니다.  
** 아래 GIt 자동 스크립트는 인터넷이 작동 되는 상태에서 진행 되어야 합니다.

### 먼저 git 사용방법을 간략하게 확인 하시기 바랍니다.    
#### - [1분 git 사용 방법 (리눅스 터미널에서)][how-to-git]  
[how-to-git]:https://github.com/dasandata/LISR/blob/master/how-to-git.md

#### 아래 표준안의 경우 LAS 자동 스크립트를 기반으로 수동 설치시 사용 할 수 있게 제작되었습니다.

## 목차
- [1. 리눅스 설치 표준안 - (2025.11)]  

  - 운영체제별 수동 설치 방법
      - [RHEL  8](https://github.com/dasandata/LAS/blob/master/RHEL%208%20Manual/RHEL_8_Install_Guide.md)
      - [RHEL  9](https://github.com/dasandata/LAS/blob/master/RHEL%209%20Manual/RHEL_9_Install_Guide.md)
      - [RHEL  10](https://github.com/dasandata/LAS/blob/master/RHEL%2010%20Manual/RHEL_10_Install_Guide.md)
      - [Ubuntu 20.04](https://github.com/dasandata/LAS/blob/master/Ubuntu%2020.04%20Manual/Ubuntu_20_Install_Guide.md)
      - [Ubuntu 22.04](https://github.com/dasandata/LAS/blob/master/Ubuntu%2022.04%20Manual/Ubuntu_22_Install_Guide.md)
      - [Ubuntu 22.04](https://github.com/dasandata/LAS/blob/master/Ubuntu%2024.04%20Manual/Ubuntu_24_Install_Guide.md)

- [2. 자동 스크립트](https://github.com/dasandata/LAS/blob/master/Linux_Auto_Script.sh)

- [3. Release Note](https://github.com/dasandata/LAS/blob/master/Release_Note.md)


[root@dasandata-script-test:~]# yum install -y git  # RHEL Linux

[root@dasandata-script-test:~]#

[root@dasandata-script-test:~]# apt-get install -y git # Ubuntu

[root@dasandata-script-test:~]#

[root@dasandata-script-test:~]# git clone https://github.com/dasandata/LAS

[root@dasandata-script-test:~]#

[root@dasandata-script-test:~]# bash /root/LAS/Linux_Auto_Script.sh

      You have run Linux_Automatic_Script
      Copyright by Dasandata.co.ltd
      http://www.dasandata.co.kr

      Linux_Automatic_Script Install Start

      CUDA Version Select
      1) 10-0
      2) 10-1
      3) 10-2
      4) 11-0
      5) No-GPU
      #? 


***

end.
