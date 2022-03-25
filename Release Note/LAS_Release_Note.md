# Linux Automatic Sript(LAS) Release Note
#### 오류 발생 및 요청사항에 대한 피드백은 Teams로 문의 부탁드립니다.
#### 다산데이타 권문주

## 2203 LAS Release Note

### == 수정된 사항 ==
```
설치 중 사용되는 Log 위치를 실행 부분에 따라 변경 완료

==== CentOS 7.9 ====
pip(python2.7)에 setuptools의 지원 종료로 tensorflow-gpu 1.13.1 버전 설치불가로 삭제
pip(python2.7)에 torch,torchvision 설치시 setuptools 40 버전으로 변경
```
### == 추가된 사항 ==
```
Rocky Linux 8.5 자동 스크립트에 내용 추가
```

## 2201 LAS Release Note

### == 수정된 사항 ==
```
JupyterHub 설치시 필요한 nodejs 버전 16으로 변경
GUI 버전에서 Network Manager 사용하도록 변경
JupyterHub 설치시 첫 화면 jupyterlab으로 변경
```

## 2112 LAS Release Note

### == 수정된 사항 ==
```
설치 표준안 작성 (Installing LISR Manually)
스크립트 완료 후 재부팅 방법 변경
CentOS X11 관련 패키지 추가 설치
CUDA 저장소에 맞게 버전 추가 및 삭제 작업 진행
```

## 2111 LAS Release Note

### == 수정된 사항 ==
```
Ubuntu, CentOS rc.local 서비스 재시작 기능 추가
Ubuntu 16에서 R, R-Server 버전 업그레이드로 인해 설치시 필요한 패키지 추가
(libssl-dev build-essential libffi-dev)
CentOS 7 에서 JupyterHub 설치시 필요한 Nodejs 버전 업그레이드로 인한 Nodejs 버전 업
Nodejs14 -> 16 으로 버전 업
설치 가능한 CUDA 버전 추가
Jupyterhub GPU 없는 버전에서 설치 안되게 변경
```

## 2108 LAS Release Note

### == 수정된 사항 ==
```
Ubuntu 20.04에서 Mirror 주소 변경 방법 변경
각 OS별 패키지 설치 종류 변경
CUDA 설치시 체크 방법 변경
설치 후 Check 시스템 이름 변경 LAS_Install_Log -> Auto_Install_Log
mailutils 기능 삭제
```


## 2107 LAS Release Note

### == 새로운 기능 ==
```
여러번 스크립트가 실행 되어도 동일한 결과값을 내는 멱등성 지원
Server, Workstation, PC 등 H/W 종류에 따른 설치 지원
OS 종류에 상관없이 진행 되는 기능 지원
CUDA 버전을 미리 선택하여 원하는 버전 설치 가능
종료 후 스스로 체크리스트 실행하여 결과값 도출까지 진행
```

### == 기존 기능 강화 ==
```
여러 갈래로 나눠진 스크립트 통합
스크립트 내의 변동사항 발생시 적용하기 용이하게 변경
설치 순서 변화로 재부팅 횟수를 줄여 속도 개선
```
### == 버그 수정 ==
```
Python3 라이브러리가 정수값을 로드하는 방식 변경으로 Warring 발생 아래 2개의 파일의 값 변경
/usr/lib/python3/dist-packages/secretstorage/dhcrypto.py : 15번째 줄
/usr/lib/python3/dist-packages/secretstorage/util.py : 19번째 줄
mailutils 설정 중 테스트 메일로 가득차서 초기화 진행
```