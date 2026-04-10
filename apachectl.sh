#!/bin/bash

# ===============================================================
# 프로그램명: Apache HTTPD 통합 관리 시스템 (Ultimate Edition)
# 목적: 설치, 제어, Vhost 추가, SSL 교체의 완전 자동화
# ===============================================================

INVENTORY="inventory_apache.ini"
ANSIBLE_USER="cdc"
ANSIBLE_PASS="ehdqn5401!"

# [초기 설정] 대상 서버 및 계정 정보 수집
echo "===== [시스템 초기 설정 및 인벤토리 구성] ====="
read -r -p "대상 서버 IP 입력 (기본: 172.28.100.117) : " SERVER_IPS
SERVER_IPS=${SERVER_IPS:-"172.28.100.117"}

read -r -p "Apache 실행 계정 입력 (기본: webadm) : " apache_user
apache_user=${apache_user:-"webadm"}
read -r -p "Apache 실행 그룹 입력 (기본: webadm) : " apache_group
apache_group=${apache_group:-"webadm"}

# 인벤토리 파일 자동 생성
IFS=',' read -ra IPS <<< "$SERVER_IPS"
: > "$INVENTORY"
echo "[apache_servers]" >> "$INVENTORY"
for ip in "${IPS[@]}"; do
    ip="$(echo "$ip" | xargs)"
    [ -n "$ip" ] && echo "$ip" >> "$INVENTORY"
done

cat >> "$INVENTORY" << EOF

[apache_servers:vars]
ansible_user=${ANSIBLE_USER}
ansible_password=${ANSIBLE_PASS}
ansible_become=true
ansible_become_method=su
ansible_become_user=root
ansible_become_password=${ANSIBLE_PASS}
ansible_python_interpreter=/usr/bin/python3
EOF

# --- [기능 함수 정의 구간] ---

# 1. Apache 소스 설치 함수
function install_apache() {
    while true; do
        echo ""
        echo "---------------------------------------------------------------"
        echo "      [Apache HTTPD 버전 선택 가이드]"
        echo "---------------------------------------------------------------"
        echo " 1) 2.4.62 (권장)  2) 2.4.59 (안정)  3) 2.4.58 (호환)  B) 뒤로"
        echo "---------------------------------------------------------------"
        read -p "선택 (또는 버전 직접 입력): " v_choice
        [[ "$v_choice" == [Bb]* ]] && return

        case $v_choice in
            1) version="2.4.62" ;;
            2) version="2.4.59" ;;
            3) version="2.4.58" ;;
            *) version=${v_choice:-"2.4.62"} ;;
        esac

        echo ">>> Apache $version 설치를 진행하시겠습니까? (y/n)"
        read -p "> " confirm
        [[ "$confirm" == [Yy]* ]] || continue

        ansible-playbook -i $INVENTORY install_apache.yml \
          -e "httpd_version=$version install_path=/data/apache apache_user=$apache_user apache_group=$apache_group"
        break
    done
}

# 2. 서비스 제어 및 포트 관리 함수
function control_apache() {
    while true; do
        echo ""
        echo "---------------------------------------------------------------"
        echo "      [서비스 제어 및 포트 관리]"
        echo "---------------------------------------------------------------"
        echo " 1) 시작  2) 정지  3) 재시작  4) 포트 변경  B) 뒤로"
        echo "---------------------------------------------------------------"
        read -p "작업 선택: " act_num
        [[ "$act_num" == [Bb]* ]] && return

        case $act_num in
            1) action="start" ;;
            2) action="stop" ;;
            3) action="restart" ;;
            4)
                read -p "변경할 신규 포트 번호 (기본: 80): " new_port
                new_port=${new_port:-"80"}
                ansible-playbook -i $INVENTORY control_apache.yml \
                  -e "action=change_port new_port=$new_port install_path=/data/apache"
                break ;;
            *) echo "잘못된 선택입니다."; continue ;;
        esac

        ansible-playbook -i $INVENTORY control_apache.yml -e "action=$action install_path=/data/apache"
        break
    done
}

# 3. 가상호스트 추가 함수
function add_vhost() {
    while true; do
        echo ""
        echo "---------------------------------------------------------------"
        echo "      [가상호스트(VirtualHost) 설정 추가]"
        echo "---------------------------------------------------------------"
        read -p "가상호스트 포트 (기본: 8080, B: 뒤로가기): " v_port
        [[ "$v_port" == [Bb]* ]] && return
        v_port=${v_port:-"8080"}

        read -p "연결 방식 (jk / proxy / 기본: jk): " conn_method
        conn_method=${conn_method:-"jk"}

        read -p "백엔드 포트 (기본: 9029): " b_port
        b_port=${b_port:-"9029"}

        echo ">>> 포트 $v_port ($conn_method) 설정을 적용하시겠습니까? (y/n)"
        read -p "> " confirm
        [[ "$confirm" == [Yy]* ]] || continue

        ansible-playbook -i $INVENTORY add_vhost.yml \
          -e "vhost_port=$v_port conn_method=$conn_method backend_port=$b_port"
        break
    done
}

# 4. SSL 인증서 교체 함수
function change_ssl() {
    while true; do
        echo ""
        echo "---------------------------------------------------------------"
        echo "      [SSL 인증서 실시간 교체 (Change)]"
        echo "---------------------------------------------------------------"
        echo ">>> 소스: /ansible/apache/ssl/ (server.crt, server.key)"
        echo ">>> 대상: /data/apache/conf/ssl/"
        echo "---------------------------------------------------------------"
        read -p "인증서를 교체하시겠습니까? (y/n, B: 뒤로): " confirm
        [[ "$confirm" == [Bb]* ]] && return
        
        if [[ "$confirm" == [Yy]* ]]; then
            ansible-playbook -i $INVENTORY change_ssl.yml \
              -e "apache_user=$apache_user apache_group=$apache_group"
            break
        else
            continue
        fi
    done
}

# --- [메인 인터페이스 루프] ---
while true; do
    echo ""
    echo "======================================"
    echo "   [작전명: 앤서블 상병 구하기] Menu"
    echo "======================================"
    echo "1. Apache 소스 컴파일 설치 (구성 포함)"
    echo "2. 서비스 제어 및 포트 관리"
    echo "3. 가상호스트(VirtualHost) 설정 추가"
    echo "4. SSL 인증서 교체 및 적용 (Change)"
    echo "0. 프로그램 종료"
    echo "======================================"
    read -p "선택: " menu

    case $menu in
        1) install_apache ;;
        2) control_apache ;;
        3) add_vhost ;;
        4) change_ssl ;;
        0) echo "감사합니다."; exit 0 ;;
        *) echo "잘못된 입력입니다. 다시 선택하십시오." ;;
    esac
done
