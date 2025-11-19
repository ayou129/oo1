#!/bin/bash
# 分批保存 sglang builder-r38.4.arm64 镜像

BUILD_DIR="/tmp/thor_build"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

mkdir -p "$BUILD_DIR"

# 获取所有符合条件的镜像，按大小排序（从小到大）
IMAGES=($(docker images --filter "reference=sglang:builder-r38.4.arm64*" --format "{{.Size}}\t{{.Repository}}:{{.Tag}}" | sort -h | cut -f2))

if [ ${#IMAGES[@]} -eq 0 ]; then
    echo -e "${YELLOW}未找到 builder-r38.4.arm64* 镜像${NC}"
    exit 0
fi

# 检测已保存的镜像
SAVED=0
for img in "${IMAGES[@]}"; do
    FILENAME=$(echo "$img" | sed 's/[:\/]/_/g').tar.gz
    [ -f "${BUILD_DIR}/${FILENAME}" ] && ((SAVED++))
done

TOTAL=${#IMAGES[@]}
PENDING=$((TOTAL - SAVED))

echo -e "${BLUE}=== SGLang 镜像保存 ===${NC}"
echo "总镜像数: ${TOTAL} | 已保存: ${SAVED} | 待保存: ${PENDING}"
echo

[ $PENDING -eq 0 ] && echo -e "${GREEN}✓ 所有镜像已保存${NC}" && exit 0

# 交互式输入
while true; do
    read -p "本次保存数量 (默认5): " BATCH
    BATCH=${BATCH:-5}
    [[ $BATCH =~ ^[0-9]+$ ]] && [ $BATCH -gt 0 ] && break
    echo -e "${RED}请输入有效数字${NC}"
done

# 处理 n 个镜像
COUNT=0
for img in "${IMAGES[@]}"; do
    FILENAME=$(echo "$img" | sed 's/[:\/]/_/g').tar.gz
    FILEPATH="${BUILD_DIR}/${FILENAME}"

    # 跳过已保存
    [ -f "$FILEPATH" ] && continue

    echo -e "${BLUE}[$((++COUNT))/$BATCH] 保存: ${img}${NC}"

    if [ -f "$FILEPATH" ]; then
        read -p "文件已存在，覆盖? (y/n): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && echo "  ⊘ 跳过" && continue
    fi

    docker save "$img" | gzip > "$FILEPATH"
    SIZE=$(du -h "$FILEPATH" | cut -f1)
    echo -e "${GREEN}  ✓ (${SIZE})${NC}"

    [ $COUNT -eq $BATCH ] && break
done

echo
SAVED=$((SAVED + COUNT))
PENDING=$((TOTAL - SAVED))
echo "已保存: ${SAVED}/${TOTAL}"

if [ $PENDING -gt 0 ]; then
    read -p "继续? (y/n): " -n 1 -r
    [ "$REPLY" = "y" ] && exec "$0"
fi
