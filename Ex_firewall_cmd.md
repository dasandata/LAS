####################
#최초 생성 2023.01.16
#대상 RHEL / FEDORA / CENTOS / ROCKY
####################

firewall-cmd 기본설정 예시)

방화벽 실행 여부 확인
firewall-cmd --state

방화벽 다시 로드
firewall-cmd --reload

존(zone) 출력하기
firewall-cmd --get-zones

존(zone) 기본 목록을 출력
firewall-cmd --get-default-zone

존(zone) 활성 목록 출력
firewall-cmd --get-active-zones

모든 서비스 포트 출력
firewall-cmd --list-all

Public 존에 속한 서비스 포트 출력
firewall-cmd --zone=public --list-all

ftp 서비스 추가
firewall-cmd --add-service=ftp

ftp 서비스 제거
firewall-cmd --remove-service=ftp

ssh 서비스 추가
firewall-cmd --add-port=21/tcp

ssh 서비스 제거
firewall-cmd --remove-port=21/tcp

Trust 존에 ftp 서비스 추가 바로적용
firewall-cmd --zone=trusted --add-service=ftp

Trust 존에 ftp 서비스 추가 영구적용(재부팅후)
firewall-cmd --permanent --add-service=ftp

Tomcat UDP 포트 추가
firewall-cmd --permanent --add-port=8080/udp

ntp TCP 포트 추가 PUBLIC 존
firewall-cmd --zone=trusted --permanent --remove-port=123=/tcp

http 서비스 추가 PUBLIC 존
firewall-cmd --zone=public --permanent --add-service=http

1.1.1.1/1523 (UDP/IN) -> LOCAL 접근 허용 
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address 1.1.1.1 port="1523" protocol="udp" accept'
