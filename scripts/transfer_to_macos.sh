#!/bin/bash
# SCP 传输镜像到 macOS
# 参数支持: -h/--host IP, -t/--target 目标路径, -y 自动覆盖

set -e

# 默认参数
MACOS_IP="192.168.3.133"
MACOS_USER="ay"
TARGET_DIR="/Users/ay/Desktop/thor_build"
SOURCE_DIR="/tmp/thor_build"
AUTO_OVERWRITE=false

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 函数：显示帮助
show_help() {
    cat << EOF
用法: ./transfer_to_macos.sh [选项]

选项:
  -h, --host IP          macOS 的 IP 地址 (默认: 192.168.3.133)
  -t, --target DIR       macOS 目标目录 (默认: /Users/ay/Desktop/thor_build)
  -u, --user USER        macOS 用户名 (默认: ay)
  -y, --yes              自动覆盖，不提示
  --help                 显示此帮助信息

示例:
  ./transfer_to_macos.sh                          # 使用默认参数
  ./transfer_to_macos.sh -h 192.168.3.100         # 自定义 IP
  ./transfer_to_macos.sh -t /Users/ay/Downloads   # 自定义目标
  ./transfer_to_macos.sh -y                       # 自动覆盖
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            MACOS_IP="$2"
            shift 2
            ;;
        -t|--target)
            TARGET_DIR="$2"
            shift 2
            ;;
        -u|--user)
            MACOS_USER="$2"
            shift 2
            ;;
        -y|--yes)
            AUTO_OVERWRITE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

echo -e "${BLUE}=== macOS 镜像传输脚本 ===${NC}"
echo "源目录: ${SOURCE_DIR}"
echo "目标主机: ${MACOS_USER}@${MACOS_IP}"
echo "目标目录: ${TARGET_DIR}"
echo

# 检查源目录
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}✗ 源目录不存在: ${SOURCE_DIR}${NC}"
    exit 1
fi

# 获取要传输的文件
FILES=($(find "$SOURCE_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.txt" \) 2>/dev/null | sort))

if [ ${#FILES[@]} -eq 0 ]; then
    echo -e "${RED}✗ 源目录中没有可传输的文件${NC}"
    exit 1
fi

echo -e "${BLUE}找到 ${#FILES[@]} 个文件:${NC}"
for f in "${FILES[@]}"; do
    SIZE=$(du -h "$f" | cut -f1)
    echo "  $(basename $f) ($SIZE)"
done
echo

# 检查 macOS 连接
echo -e "${BLUE}检查 macOS 连接...${NC}"
if ! ping -c 1 -W 2 "$MACOS_IP" > /dev/null 2>&1; then
    echo -e "${RED}✗ 无法连接到 ${MACOS_IP}${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 连接成功${NC}"
echo

# 创建远程目录
echo -e "${BLUE}准备远程目录...${NC}"
ssh "${MACOS_USER}@${MACOS_IP}" "mkdir -p '${TARGET_DIR}'" 2>/dev/null
echo -e "${GREEN}✓ 目录已准备${NC}"
echo

# 处理文件冲突
DECLARE_OVERWRITE_ALL=false
declare -A OVERWRITE_DECISION

echo -e "${BLUE}检查文件冲突...${NC}"
for FILE in "${FILES[@]}"; do
    BASENAME=$(basename "$FILE")
    REMOTE_FILE="${TARGET_DIR}/${BASENAME}"

    # 检查远程文件是否存在
    if ssh "${MACOS_USER}@${MACOS_IP}" "[ -f '${REMOTE_FILE}' ]" 2>/dev/null; then
        LOCAL_SIZE=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE" 2>/dev/null)
        REMOTE_SIZE=$(ssh "${MACOS_USER}@${MACOS_IP}" "stat -f%z '${REMOTE_FILE}' 2>/dev/null || stat -c%s '${REMOTE_FILE}' 2>/dev/null" 2>/dev/null)

        if [ "$LOCAL_SIZE" == "$REMOTE_SIZE" ]; then
            echo -e "${YELLOW}⚠ ${BASENAME} 已存在 (大小相同)${NC}"
        else
            echo -e "${YELLOW}⚠ ${BASENAME} 已存在 (本地: $(numfmt --to=iec-i --suffix=B $LOCAL_SIZE 2>/dev/null || echo $LOCAL_SIZE), 远程: $(numfmt --to=iec-i --suffix=B $REMOTE_SIZE 2>/dev/null || echo $REMOTE_SIZE))${NC}"
        fi

        if [ "$AUTO_OVERWRITE" = true ]; then
            OVERWRITE_DECISION["$BASENAME"]=1
            echo "  → 自动覆盖"
        elif [ "$DECLARE_OVERWRITE_ALL" = true ]; then
            OVERWRITE_DECISION["$BASENAME"]=1
        else
            read -p "  [O]覆盖 [S]跳过 [A]全部覆盖 [Q]退出: " -n 1 -r choice
            echo
            case "$choice" in
                O|o)
                    OVERWRITE_DECISION["$BASENAME"]=1
                    ;;
                S|s)
                    OVERWRITE_DECISION["$BASENAME"]=0
                    ;;
                A|a)
                    DECLARE_OVERWRITE_ALL=true
                    OVERWRITE_DECISION["$BASENAME"]=1
                    ;;
                Q|q)
                    echo -e "${RED}已退出${NC}"
                    exit 0
                    ;;
                *)
                    echo -e "${RED}无效选择，跳过该文件${NC}"
                    OVERWRITE_DECISION["$BASENAME"]=0
                    ;;
            esac
        fi
    else
        OVERWRITE_DECISION["$BASENAME"]=1
    fi
done

echo
echo -e "${BLUE}开始传输...${NC}"
echo

# 传输文件
TOTAL_TRANSFERRED=0
for FILE in "${FILES[@]}"; do
    BASENAME=$(basename "$FILE")

    if [ "${OVERWRITE_DECISION[$BASENAME]}" != "1" ]; then
        echo -e "${YELLOW}⊘ 跳过: ${BASENAME}${NC}"
        continue
    fi

    LOCAL_SIZE=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE" 2>/dev/null)
    SIZE_HUM=$(du -h "$FILE" | cut -f1)

    echo -e "${BLUE}传输: ${BASENAME} (${SIZE_HUM})${NC}"

    # 使用 scp 传输，显示进度
    if scp -p "$FILE" "${MACOS_USER}@${MACOS_IP}:${TARGET_DIR}/" 2>&1 | grep -q "100%\|transmitted"; then
        # 验证文件大小
        REMOTE_SIZE=$(ssh "${MACOS_USER}@${MACOS_IP}" "stat -f%z '${TARGET_DIR}/${BASENAME}' 2>/dev/null || stat -c%s '${TARGET_DIR}/${BASENAME}' 2>/dev/null" 2>/dev/null)

        if [ "$LOCAL_SIZE" == "$REMOTE_SIZE" ]; then
            echo -e "${GREEN}✓ 完成 (已验证)${NC}"
            ((TOTAL_TRANSFERRED++))
        else
            echo -e "${RED}✗ 验证失败 (本地: ${LOCAL_SIZE}, 远程: ${REMOTE_SIZE})${NC}"
        fi
    else
        echo -e "${RED}✗ 传输失败${NC}"
    fi
    echo
done

echo -e "${BLUE}=== 传输完成 ===${NC}"
echo "成功传输: ${TOTAL_TRANSFERRED}/${#FILES[@]} 个文件"
echo -e "${GREEN}✓ 镜像已传输到 macOS: ${TARGET_DIR}${NC}"
