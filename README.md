# 안녕하세요 다산데이타 입니다.  
다산데이타 에서 출고되는 서버 & 워크스테이션에 설치되는 리눅스 표준설치 메뉴얼 과 스크립트 입니다.  
** 아래 GIt 자동 스크립트는 인터넷이 작동 되는 상태에서 진행 되어야 합니다.

![Dasandata Logo](http://dasandata.co.kr/wp-content/uploads/2019/05/%EB%8B%A4%EC%82%B0%EB%A1%9C%EA%B3%A0_%EC%88%98%EC%A0%951-300x109.jpg)

### 먼저 git 사용방법을 간략하게 확인 하시기 바랍니다.    
#### - [1분 git 사용 방법 (리눅스 터미널에서)][how-to-git]  
[how-to-git]:https://github.com/dasandata/LISR/blob/master/how-to-git.md

#### 아래 표준안의 경우 LAS 자동 스크립트를 기반으로 수동 설치시 사용 할 수 있게 제작되었습니다.

## 목차
- [1. 리눅스 설치 표준안 - (2022.03)]  

  - 운영체제 통합 스크립트
      - [centos 7.9](https://github.com/dasandata/LAS/blob/ce0932c463fa3fc06617e3859c80a641008e4be8/CentOS%207.9%20Manual/CentOS_7_Install_Guide.md)
      - [rocky  8.5](https://github.com/dasandata/LAS/blob/ce0932c463fa3fc06617e3859c80a641008e4be8/Rocky%208.5%20Manual/Rocky_8_install_guide.md)
      - [ubuntu 18.04](https://github.com/dasandata/LAS/blob/ce0932c463fa3fc06617e3859c80a641008e4be8/Ubuntu%2018.04%20Manual/Ubuntu_18_Install_Guide.md)
      - [ubuntu 20.04](https://github.com/dasandata/LAS/blob/ce0932c463fa3fc06617e3859c80a641008e4be8/Ubuntu%2020.04%20Manual/Ubuntu_20_Install_Guide.md)

- [4. 자동 스크립트 Release Note ](https://github.com/dasandata/LAS/blob/88da18550bf95d744024adf16aab93a0fcb59005/Release%20Note/LAS_Release_Note.md)


[root@dasandata-script-test:~]#  yum install -y git  # Centos , Rocky Linux

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






## 기타
- [마크다운에 대하여][markdown]
***

end.
