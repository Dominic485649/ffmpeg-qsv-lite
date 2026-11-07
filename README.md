# FFmpeg QSV Lite · Windows x64

面向 Intel GPU 的 FFmpeg 构建，使用 oneVPL，提供 **HEVC / AV1 硬件编码、QSV VPP、现代 D3D11/D3D12 硬解、libplacebo，以及 AAC / Opus 音频处理**。

程序采用静态链接，运行文件为单个 **`ffmpeg.exe`**，适合本地文件转码与 FFmpegFreeUI 的 Intel 工作流。

[下载 Release](https://github.com/Dominic485649/ffmpeg-qsv-lite/releases) · [Full](https://github.com/Dominic485649/ffmpeg-full) · [NVENC Lite](https://github.com/Dominic485649/ffmpeg-nvenc-lite)

## 主要功能

| 类别 | 提供的能力 |
|---|---|
| 视频编码 | **`hevc_qsv`、`av1_qsv`** |
| 原始帧输出 | `rawvideo` |
| 音频编码 | 原生 `aac`（含 NMR 参数）、`libopus` |
| 视频解码 | H.264、HEVC、AV1、VP8/VP9、MPEG-2/4、VC-1、MJPEG、ProRes、原生 AVS1 等白名单 |
| 音频解码 | AAC、MP3、AC-3/E-AC-3、TrueHD、DTS、FLAC、Opus、WavPack、ALAC、部分 PCM 等白名单 |
| Windows 硬解 | H.264、HEVC、AV1、VP9、VC-1、MPEG-2 的 D3D11/D3D12 路径 |
| QSV 滤镜 | `vpp_qsv`、`scale_qsv`、`deinterlace_qsv`、`overlay_qsv`、`hstack_qsv`、`vstack_qsv`、`xstack_qsv` |
| 图像与色彩处理 | libplacebo、Vulkan、Shaderc、SPIR-V 与硬件上下文互操作 |
| CPU 与基础滤镜 | `scale`、`crop`、`fps`、旋转、翻转、时间戳处理与硬件帧上传/下载 |
| 音频处理 | SoXR 重采样与基础音频格式、时间戳处理 |
| 常用文件 | Matroska、MP4/MOV、MPEG-TS、Ogg、WAV、FLAC，以及白名单中的裸流与原始数据 |
| 输入输出协议 | `file`、`pipe`，用于本地文件与管道工作流 |
| 元数据与比特流处理 | HEVC HDR Vivid T.35 元数据解析、上游 Dolby Vision 相关解析、`dovi_rpu` / `dovi_split` |

可通过 `-encoders`、`-decoders`、`-filters`、`-demuxers`、`-muxers` 查询程序的实际功能列表。硬件能力取决于 GPU 型号、驱动、编码格式和输入素材。

## 下载与安装

从 [Releases](https://github.com/Dominic485649/ffmpeg-qsv-lite/releases) 选择版本并查看对应说明。

- 使用该版本提供的 `*-setup.exe` 时，可运行 7-Zip SFX 安装器，选择有写入权限的目录，并决定是否加入当前用户 PATH。
- 便携使用时，可用 7-Zip 提取 `ffmpeg.exe` 并按需手动设置 PATH。
- 运行环境为 **64 位 Windows**，CPU 须满足 **x86-64-v3（含 AVX2 等指令）**。
- 硬件处理需要提供对应 oneVPL/QSV 能力的 Intel GPU 与驱动；AV1 编码需使用具备 AV1 编码能力的型号。
- 单 EXE 采用静态链接，并通过 Windows 系统组件、Intel 媒体驱动与相应 Vulkan 运行时使用硬件。

设置 PATH 后重新打开终端。以下命令假定 `ffmpeg.exe` 已加入 PATH，也可使用完整路径。

```bash
ffmpeg.exe -version
```

```bash
ffmpeg.exe -encoders
```

```bash
ffmpeg.exe -filters
```

## 使用示例

以下视频命令用于普通 SDR 转码；HDR 工作流应根据素材匹配位深、色彩信息与处理链。

### HEVC 硬件编码

```bash
ffmpeg.exe -i input.mkv -map 0:v:0 -map "0:a:0?" -c:v hevc_qsv -global_quality 24 -c:a aac -b:a 192k output-hevc.mkv
```

### AV1 硬件编码

```bash
ffmpeg.exe -i input.mkv -map 0:v:0 -map "0:a:0?" -c:v av1_qsv -global_quality 28 -c:a libopus -b:a 128k output-av1.mkv
```

质量参数应按编码格式、素材和目标体积分别调节。

### QSV VPP 缩放与 HEVC 编码

此示例选择 Intel D3D11 设备并派生 QSV，视频解码使用软件路径。输入必须是**已知 25 fps 的恒定帧率素材**；输出在 VPP 后按该帧率显式重建时间戳：

```bash
ffmpeg.exe -init_hw_device d3d11va=dx:,vendor_id=0x8086 -init_hw_device qsv=qs@dx -filter_hw_device qs -i input-25fps.mkv -map 0:v:0 -map "0:a:0?" -vf "format=nv12,vpp_qsv=w=1920:h=1080,setpts=N/(25*TB)" -c:v hevc_qsv -low_power 1 -async_depth 1 -b:v 4M -c:a aac -b:a 192k output-1080p.mkv
```

本机 FFmpeg/QSV/驱动组合的系统内存 VPP 路径存在时间戳丢失、零帧输出的情况。重建时间戳仅适用于帧率与起点明确的输入，不能直接套用于可变帧率素材；有音频时还需确认音画起点与同步。请核对实际输出帧数和时长，不要仅以进程退出成功判断处理完成。

### D3D11 / D3D12 硬解检查

下面针对受支持的 8-bit HEVC 输入，下载硬件帧并以 `rawvideo` 输出至空封装：

```bash
ffmpeg.exe -hwaccel d3d11va -hwaccel_output_format d3d11 -i input-hevc.mkv -map 0:v:0 -an -vf "hwdownload,format=nv12" -c:v rawvideo -f null -
```

```bash
ffmpeg.exe -hwaccel d3d12va -hwaccel_output_format d3d12 -i input-hevc.mkv -map 0:v:0 -an -vf "hwdownload,format=nv12" -c:v rawvideo -f null -
```

其他位深的素材应使用匹配的下载像素格式。设备选择和处理路径可通过日志确认。

### SoXR 重采样与 Opus 编码

```bash
ffmpeg.exe -i input.wav -vn -af "aresample=48000:resampler=soxr" -c:a libopus -b:a 128k -f ogg output.ogg
```

### 原生 AAC / NMR

```bash
ffmpeg.exe -i input.wav -vn -c:a aac -aac_coder nmr -aac_nmr_speed 0 -b:a 192k output.m4a
```

## 从源码构建

在 Linux/WSL2 中交叉编译，使用完整配套的根 `ffmpeg.sh`、`scripts/`、`shared-patches/` 和 `build-manifests/write_manifest.py`。

构建环境包括受管理的 LLVM-MinGW、CMake、Ninja、Meson、NASM、Make、pkg-config、Git、Python 3，以及用于构建 host-glslc 的原生 C/C++ 编译器。

工具安装入口见 [Full 仓库的构建说明](https://github.com/Dominic485649/ffmpeg-full#从源码构建)。准备 QSV 环境时，可在 **Full 仓库根目录**运行以下工具准备命令：

```bash
CUDA_ENABLE=0 CUDA_TOOLKIT_ENABLE=0 ./ffmpeg.sh tool
```

完成后回到 **QSV Lite 仓库根目录**更新源码：

```bash
./ffmpeg.sh update
```

使用现有源码构建：

```bash
JOBS=2 FFMPEG_JOBS=2 ./ffmpeg.sh build
```

目标 C/C++ 组件与 FFmpeg 使用 **ThinLTO**。可通过 `JOBS` 与 `FFMPEG_JOBS` 调整构建并发；上例使用两个编译作业。

不带参数或使用 `all` 会依次更新源码并构建。默认会查询并核验受管理工具链版本；工具链已准备好时，`TOOLCHAIN_REFRESH=0` 可显式复用已安装且验证有效的版本。Shaderc 固定依赖准备可能需要联网。

| 用途 | 默认路径 |
|---|---|
| 依赖源码 | `sources/` |
| 依赖安装前缀 | `bin_qsv/` |
| 构建与内容缓存 | `build_qsv/` |
| 最终程序 | **`qsv/ffmpeg.exe`** |

目标外部依赖为 oneVPL、Opus、SoXR、Shaderc、Vulkan-Headers 和 libplacebo，另有原生 host-glslc 构建阶段。阶段缓存按源码、配置、工具链、依赖和产物内容核验；构建清单记录实际提交、参数与程序身份。FFmpeg 默认跟踪 `master`。

## FFmpegFreeUI 预设

若 Release 附带 JSON，可作为 [FFmpegFreeUI](https://github.com/Lake1059/FFmpegFreeUI) v6 用户预设放入 `Preset_v6\User`。预设作为可选独立附件提供；使用前请确认编码器、滤镜与本机路径匹配。

## 实测与许可证

2026-11-07 本地产物已通过隔离单 EXE 运行、系统/驱动依赖、PE64/CFG、实际 ThinLTO 产物核验与完整离线回归。在 Intel Arc 上完成 HEVC/AV1 直接编码及 VPP 缩放，QSV 会话采用 Intel D3D11 派生设备；VPP 使用已知恒定帧率并显式重建时间戳，逐项核对实际输出帧数。

D3D11/D3D12 HEVC 硬解、硬件帧下载、libplacebo/Vulkan 实际处理、SoXR、NMR AAC、Opus 编解码往返与原生 Ogg/Opus 解码通过。系统内存 VPP 的时间戳使用条件见上方示例；本机所测显式硬件上传的纹理创建路径未通过，不将其计为通过项。

各版本的程序身份、文件体积与验证信息见对应 Release。

自有脚本与文档采用 [MIT License](https://github.com/Dominic485649/ffmpeg-qsv-lite/blob/main/LICENSE)。当前 FFmpeg 许可证标识为 **`LGPL version 2.1 or later`**；FFmpeg、外部库、Intel 驱动与安装器组件适用各自许可证，使用与分发须满足相应许可要求。
