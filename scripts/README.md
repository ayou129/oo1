脚本 1：分批保存镜像
/home/ay/Desktop/app/oo1/scripts/save_sglang_images.sh
- 自动检测已保存镜像
- 交互式输入批处理数量（默认5）
- 导出为 tar.gz 到 /tmp/thor_build/
- 文件存在时确认覆盖

脚本 2：传输到 macOS
/home/ay/Desktop/app/oo1/scripts/transfer_to_macos.sh [选项]
- 支持 -h (IP) -u (用户) -t (目标路径) -y (自动覆盖)
- 自动检查连接和文件冲突
- 验证传输后文件大小
- 使用 SSH 创建远程目录