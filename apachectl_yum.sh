#!/bin/bash

INVENTORY="inventory_apache.ini"
ANSIBLE_USER="cdc"
ANSIBLE_PASS="ehdqn5401!"

echo "===== [YUM 초기 설정] ====="
read -r -p "대상 서버 IP 입력 (기본: 172.28.100.117) : " SERVER_IPS
SERVER_IPS=${SERVER_IPS:-"172.28.100.117"}

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

function install_apache_yum() {
    while true; do
        echo -e "\n1. Apache YUM 설치 (구성 포함)  B. 뒤로"
        read -p "선택: " v_choice
        [[ "$v_choice" == [Bb]* ]] && return

        read -p "설치를 진행하시겠습니까? (y/n): " confirm
        if [[ "$confirm" == [Yy]* ]]; then
            ansible-playbook -i $INVENTORY install_apache_yum.yml
            break
        fi
    done
}

function control_apache() {
    while true; do
        echo -e "\n1) 시작  2) 정지  3) 재시작  4) 포트 변경  B) 뒤로"
        read -p "선택: " act_num
        [[ "$act_num" == [Bb]* ]] && return

        case $act_num in
            1) action="start" ;;
            2) action="stop" ;;
            3) action="restart" ;;
            4)
                read -p "변경할 포트 번호: " new_port
                ansible-playbook -i $INVENTORY control_apache.yml -e "action=change_port new_port=${new_port:-80} install_path=/etc/httpd"
                break ;;
            *) continue ;;
        esac

        ansible-playbook -i $INVENTORY control_apache.yml -e "action=$action install_path=/etc/httpd"
        break
    done
}

function add_vhost() {
    while true; do
        echo -e "\n[가상호스트 설정 추가]"
        read -p "포트 (기본: 8080, B: 뒤로가기): " v_port
        [[ "$v_port" == [Bb]* ]] && return
        v_port=${v_port:-"8080"}

        read -p "연결 방식 (jk / proxy): " conn_method
        read -p "백엔드 포트 (기본: 9029): " b_port
        
        read -p "적용하시겠습니까? (y/n): " confirm
        [[ "$confirm" == [Yy]* ]] || continue

        ansible-playbook -i $INVENTORY add_vhost.yml -e "vhost_port=$v_port conn_method=${conn_method:-jk} backend_port=${b_port:-9029}"
        break
    done
}

function change_ssl() {
    while true; do
        echo -e "\n[SSL 인증서 교체]"
        read -p "인증서를 교체하시겠습니까? (y/n, B: 뒤로): " confirm
        [[ "$confirm" == [Bb]* ]] && return
        
        if [[ "$confirm" == [Yy]* ]]; then
            ansible-playbook -i $INVENTORY change_ssl.yml -e "apache_user=apache apache_group=apache"
            break
        fi
    done
}

while true; do
    echo -e "\n======================================"
    echo "   [install apache - YUM]"
    echo "======================================"
    echo "1. Apache YUM 설치 (구성 포함)"
    echo "2. 서비스 제어 및 포트 관리"
    echo "3. 가상호스트(VirtualHost) 설정 추가"
    echo "4. SSL 인증서 교체 및 적용 (Change)"
    echo "0. 프로그램 종료"
    echo "======================================"
    read -p "선택: " menu

    case $menu in
        1) install_apache_yum ;;
        2) control_apache ;;
        3) add_vhost ;;
        4) change_ssl ;;
        0) exit 0 ;;
    esac
done
