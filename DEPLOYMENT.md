# OO1 Robot AI Stack - Deployment Guide

完整的 OO1 机器人 AI 系统，包含视觉、语言和语音能力。

## 架构概览

```
┌─────────────────────────────────────────────────────────┐
│                    OO1 Robot                            │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────────┐      ┌──────────────────┐        │
│  │  Faster-Whisper  │      │  SGLang (Brain)  │        │
│  │  ASR (Ears)      │      │  - VL-8B Vision  │        │
│  │  Port 8003       │      │  - 32B LLM       │        │
│  │                  │      │  Ports 8001-8002 │        │
│  └──────────────────┘      └──────────────────┘        │
│                                                           │
│  ┌──────────────────┐      ┌──────────────────┐        │
│  │   XTTS v2 TTS    │      │   isaac_ros-dev  │        │
│  │  (Mouth)         │      │   ROS2 Integration│       │
│  │  Port 8004       │      │   (Submodule)     │        │
│  │  + Voice Clone   │      │                   │        │
│  └──────────────────┘      └──────────────────┘        │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## 快速开始

### 前置要求

- Docker & Docker Compose 已安装
- NVIDIA GPU + nvidia-runtime
- 模型已下载到 `models/Qwen/`
- 128GB+ GPU 显存（推荐 Thor）

### 启动所有服务

```bash
cd /home/ay/Desktop/app/oo1

# 启动所有容器
docker-compose up -d

# 查看运行状态
docker-compose ps

# 查看日志
docker-compose logs -f sglang
docker-compose logs -f faster-whisper
docker-compose logs -f xtts
```

### 验证服务

所有服务启动后：

```bash
# 检查 SGLang (LLM)
curl http://localhost:8001/v1/models
curl http://localhost:8002/v1/models

# 检查 Faster-Whisper (ASR)
curl http://localhost:8003/health

# 检查 XTTS (TTS)
curl http://localhost:8004/health
```

### 停止所有服务

```bash
docker-compose down

# 同时删除卷（清理缓存）
docker-compose down -v
```

## 服务详情

### 1. SGLang LLM Services (Port 8001-8002)

**VL-8B Vision Model (8001)**
- 模型：Qwen3-VL-8B-Instruct-FP8
- 功能：视觉识别、图像理解、文字识别
- 内存：8 GB
- API：OpenAI-compatible

**32B Brain Model (8002)**
- 模型：Qwen3-32B-FP8
- 功能：推理决策、指令生成、ROS2 JSON 输出
- 内存：30 GB
- API：OpenAI-compatible

使用示例：
```bash
# VL 模型：图像理解
curl -X POST http://localhost:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "描述这张图"}]}'

# 32B 模型：推理决策
curl -X POST http://localhost:8002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "生成 ROS2 移动指令"}]}'
```

### 2. Faster-Whisper ASR (Port 8003)

- 模型：Faster-Whisper small
- 功能：语音识别（中文、英文）
- 内存：2-3 GB
- 计算类型：INT8
- RTF：2-4x（比实时快 2-4 倍）

使用示例：
```bash
curl -X POST http://localhost:8003/v1/audio/transcriptions \
  -F "file=@audio.wav" \
  -F "model=faster-whisper"
```

### 3. XTTS v2 TTS (Port 8004)

- 模型：XTTS v2 多语言
- 功能：文字转语音、语音克隆
- 内存：7-8 GB
- 语言：中文、英文等
- 特性：零样本语音克隆

使用示例：
```bash
# 基本合成
curl -X POST http://localhost:8004/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"text": "你好世界", "voice": "default", "language": "zh"}' \
  -o output.wav

# 语音克隆
# 1. 放置声音样本到 voices/ 目录
# 2. 使用克隆的声音
curl -X POST http://localhost:8004/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"text": "你好", "voice": "cloned_voice_name"}' \
  -o output.wav
```

## GPU 显存分配

总共 128GB Thor GPU：

```
VL-8B (SGLang)：     8 GB
32B (SGLang)：      30 GB
Faster-Whisper：     3 GB
XTTS v2：            8 GB
系统/缓存：         79 GB (包括 KV-cache、临时缓冲)
────────────────────────
总计：             128 GB
```

## 环境变量

可在 `docker-compose.yml` 中调整：

```yaml
sglang:
  environment:
    - NVIDIA_VISIBLE_DEVICES=0  # GPU ID

faster-whisper:
  environment:
    - ASR_MODEL=small           # tiny, small, medium, large
    - COMPUTE_TYPE=int8         # int8, float16, float32
    - ASR_LANGUAGE=zh           # 语言代码

xtts:
  environment:
    - TTS_LANGUAGE=zh           # 默认语言
```

## 日志

所有日志保存在 `logs/` 目录：

```bash
tail -f logs/sglang/vl-8b.log
tail -f logs/sglang/llm-32b.log
tail -f logs/asr/asr_service.log
tail -f logs/tts/tts_service.log
```

## 故障排查

### 容器无法启动

```bash
# 查看错误日志
docker-compose logs sglang
docker-compose logs faster-whisper
docker-compose logs xtts

# 检查 GPU
nvidia-smi

# 检查 Docker 驱动
docker run --rm --runtime=nvidia nvidia/cuda:12.0-runtime nvidia-smi
```

### 内存不足

```bash
# 减少并发请求数
# 修改 docker-compose.yml 中的 mem_fraction_static

# 或停止不需要的服务
docker-compose stop faster-whisper
```

### 模型加载失败

```bash
# 确保模型文件存在
ls -la models/Qwen/

# 检查模型路径
docker-compose exec sglang ls -la /models/
```

## 开发指南

### 添加新服务

1. 在 `services/` 下创建新目录
2. 编写启动脚本和配置文件
3. 在 `docker-compose.yml` 中添加服务定义
4. 更新此文档

### 修改模型配置

编辑 `docker-compose.yml` 中对应服务的 `command` 部分

### 本地测试

```bash
# 不使用 docker-compose，直接运行脚本
bash services/asr/start_asr.sh
bash services/tts/start_tts.sh

# 运行测试
python3 services/asr/test_asr.py
python3 services/tts/test_tts.py
```

## 性能优化

### 启用 Flash Attention（已默认）

编辑 SGLang 服务的 command：
```
--enable-flashinfer
--enable-dp-attention
```

### 调整 GPU 显存分配

```yaml
# 降低 VL-8B 显存占用
--mem-fraction-static 0.6

# 降低 32B 显存占用
--mem-fraction-static 0.7
```

### 缓存优化

XTTS 和 Whisper 使用 `/tmp` 缓存，可挂载本地 SSD：

```yaml
volumes:
  - /mnt/fast-ssd/cache:/tmp
```

## 集成 ROS2

见 `isaac_ros-dev/` 子项目。

启动 ROS2 bridge：

```bash
cd isaac_ros-dev
colcon build
source install/setup.bash
ros2 launch ...
```

## 常用命令速查

```bash
# 启动
docker-compose up -d

# 查看运行
docker-compose ps

# 查看日志
docker-compose logs -f

# 进入容器
docker-compose exec sglang bash

# 停止
docker-compose down

# 重启某个服务
docker-compose restart sglang

# 查看资源使用
docker stats

# 清理（谨慎操作）
docker-compose down -v  # 删除卷
docker system prune     # 删除未使用的镜像和容器
```

## 性能指标

在 NVIDIA Thor 128GB 上的预期性能：

| 服务 | 模型 | 延迟 | 吞吐 |
|------|------|------|------|
| VL-8B | Qwen3-VL | 2-3s | 8-12 tok/s |
| 32B | Qwen3-32B | 3-5s | 4-8 tok/s |
| ASR | Faster-Whisper | 2-4s | 2-4x RTF |
| TTS | XTTS | 1-3s | 0.5-1x RTF |

## 更多资源

- SGLang: https://github.com/sgl-project/sglang
- Faster-Whisper: https://github.com/SYSTRAN/faster-whisper
- XTTS: https://github.com/coqui-ai/TTS
- Qwen 模型：https://huggingface.co/Qwen
- ROS2：https://docs.ros.org/

## 许可证

见各项目许可证
