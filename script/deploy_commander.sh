#!/bin/bash
# 쪠밋! 사령관님의 명령을 입력받는 인터페이스

echo "==========================================="
echo "   제미니 하사, 지휘권 위임받았습니다!"
echo "==========================================="

# 1. 사령관님께 값 하달 받기 (세마포어 로그창에서 입력 가능)
read -p "🎯 타겟 도메인을 입력하십시오: " TARGET_DOMAIN
read -p "⚓ 개방할 포트를 입력하십시오 (기본 80): " TARGET_PORT

# 기본값 설정
TARGET_PORT=${TARGET_PORT:-80}

echo "-------------------------------------------"
echo "🚀 입력된 좌표: $TARGET_DOMAIN / $TARGET_PORT"
echo "🔥 앤서블 폭격 부대를 호출합니다..."
echo "-------------------------------------------"

# 2. 앤서블 격발 (ansible-playbook 직접 실행)
# 여기서 세마포어가 관리하는 인벤토리 파일을 자동으로 참조하도록 구성합니다.
ansible-playbook repo_based/vhost_apache_repo.yml \
  --extra-vars "target_domain=$TARGET_DOMAIN target_port=$TARGET_PORT"

echo "==========================================="
echo "   작전 종료! 사령관님 가즈아—!!!"
echo "==========================================="