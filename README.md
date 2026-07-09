# ffmpeg-qsv-lite

基于 FFmpeg master 的 Intel QSV / oneVPL 专用转码构建，面向 Windows 用户。

本项目专注于：

> 现代格式解码 → QSV 视频处理 → QSV 编码输出 HEVC / AV1

目标不是做“全功能 FFmpeg”，而是构建一个体积更小、组件更少、路径更明确的 Intel GPU 硬件转码版 `ffmpeg.exe`。

### 如果需要nvidia的nvenc硬编解码器和cuda相关滤镜支持，请看[ffmpeg-nvenc-lite](https://github.com/Dominic485649/ffmpeg-nvenc-lite)

---

## 设计目标

* 使用 Intel Quick Sync Video / oneVPL 作为核心硬件加速路径
* 优先使用 `libvpl`，而不是旧 `libmfx`
* 使用 QSV 输出 HEVC / AV1
* 保留 QSV 视频处理滤镜
* 保留常见容器输入输出能力
* 保留常见转码所需解码器
* 保留 `libfdk_aac` 和 `aac_at` 音频编码
* 禁用 x264 / x265 / SVT-AV1 / libaom / rav1e 等软件视频编码器
* 禁用 CUDA / NVENC / NPP / AMF / VAAPI / Vulkan / OpenCL 相关组件
* 禁用字幕渲染栈、质量评测滤镜、BM3D / nlmeans / hqdn3d 等非目标组件
* 尽量减少误调用 CPU 滤镜导致的性能回退

---

## 版本信息

| 项目          | 版本 / 配置                |
| ------------ | ------------------------ |
| FFmpeg       | master                   |
| Compiler     | GCC 13-posix             |
| Target       | Windows x86_64           |
| Toolchain    | Linux / WSL2 → MinGW-w64 |
| Acceleration | Intel QSV / oneVPL       |
| CPU baseline | x86-64-v3                |
| Link         | Static build             |
| ffprobe      | 默认不构建                |

---

## 编码器

| 编码器               | 类型      | 说明                                         |
| ----------------- | ------- | ------------------------------------------ |
| `hevc_qsv`        | 视频      | H.265 / HEVC QSV 硬件编码                      |
| `av1_qsv`         | 视频      | AV1 QSV 硬件编码                               |
| `aac_nmr`      | 音频      | 新版本FFmpeg默认的aac编码器                   |

> 所有通用软件视频编码器均已禁用，视频编码路径只保留 QSV。

---

## 解码器

本构建使用 decoder 白名单，而不是 FFmpeg 默认全量 decoder。

### 视频 decoder

| 类型       | 保留内容                                                                                                    |
| -------- | ------------------------------------------------------------------------------------------------------- |
| 现代主流     | `h264`, `hevc`, `av1`, `libdav1d`, `vp9`, `vp8`                                                         |
| 常见兼容     | `mpeg2video`, `mpeg4`, `msmpeg4v3`, `vc1`, `wmv3`                                                       |
| 图像输入     | `mjpeg`, `png`, `webp`, `bmp`, `tiff`, `gif`                                                            |
| 原始 / 内部  | `rawvideo`, `wrapped_avframe`                                                                           |
| QSV 硬件解码 | `h264_qsv`, `hevc_qsv`, `av1_qsv`, `mpeg2_qsv`, `mjpeg_qsv`, `vc1_qsv`, `vp8_qsv`, `vp9_qsv`, `vvc_qsv` |

`libdav1d` 用于可靠的 AV1 软件解码。对于 AV1 输入文件，如果 QSV 或 FFmpeg native AV1 路径不稳定，可以显式使用：

```powershell
.\ffmpeg.exe -c:v libdav1d -i "input_av1.mkv" ...
```

### 音频 decoder

保留常见转码和封装所需音频 decoder：

```text
aac, mp3, ac3, eac3, truehd, dca, flac, opus, vorbis,
wavpack, alac,
pcm_s16le, pcm_s24le, pcm_s32le, pcm_f32le, pcm_f64le
```

### 字幕

本构建不保留字幕解码、字幕编码、字幕烧录和字幕渲染滤镜。

目标仅保留容器层面的 `-c:s copy` 能力。字幕 copy 是否成功取决于输入 / 输出容器是否支持该字幕 packet。推荐需要保留字幕时输出 MKV。

---

## QSV 滤镜

本构建保留当前 FFmpeg 源码树中可用的 QSV 滤镜，并通过构建脚本动态解析 `*_qsv` 滤镜列表。

当前构建至少包含：

| 滤镜                | 功能                                        |
| ----------------- | ----------------------------------------- |
| `scale_qsv`       | QSV 缩放                                    |
| `vpp_qsv`         | QSV Video Post Processing，支持缩放、格式、部分增强处理等 |
| `deinterlace_qsv` | QSV 反交错                                   |
| `overlay_qsv`     | QSV 视频叠加                                  |
| `hstack_qsv`      | QSV 横向拼接                                  |
| `vstack_qsv`      | QSV 纵向拼接                                  |
| `xstack_qsv`      | QSV 多路拼接                                  |

---

## 基础软件滤镜

由于本构建使用 `--disable-filters`，仅白名单保留必要基础滤镜：

```text
format, aformat,
null, anull,
fps,
trim, atrim,
setpts, asetpts,
settb, asettb,
setparams, setsar,
aresample,
hwupload, hwdownload, hwmap
```

同时保留少量 CPU 几何滤镜作为实用回退：

```text
scale, crop, transpose, hflip, vflip, rotate
```

这些滤镜不是 QSV 滤镜。如果你追求更极限的 QSV-only 构建，可以在脚本中继续移除部分 CPU 回退滤镜。

---

## 已移除 / 不包含

### 不包含 CUDA / NVENC / NPP

本构建不启用 NVIDIA 相关组件：

```text
cuda, nvenc, nvdec, libnpp
*_cuda, *_npp
```

### 不包含 AMF / VAAPI / Vulkan / OpenCL

默认不启用：

```text
amf, vaapi, vulkan, opencl, libplacebo, zimg
```

### 不包含质量评测滤镜

本构建默认不包含：

```text
libvmaf, libvmaf_cuda, psnr, ssim, xpsnr, siti, signature
```

原因是质量评测工作流通常还依赖 `ffprobe`、双输入滤镜链、VMAF 模型、scale / format 辅助滤镜和更多分析组件。为了保持转码构建精简，本项目不默认内置评测功能。

如需质量评测，建议单独维护 `ffmpeg-eval.exe` 或 full 构建。

### 不包含字幕渲染栈

默认禁用：

```text
libass, freetype, fontconfig, fribidi, harfbuzz
subtitles, ass, drawtext, textsub
```

### 不包含 FFmpeg 原生 BM3D / CPU 降噪滤镜

当前 FFmpeg 构建不包含：

```text
bm3d
nlmeans
hqdn3d
```

本项目不提供 BM3D、AI 降噪或额外降噪生态。
注意：`vpp_qsv` 本身属于 QSV 视频处理组件，因此作为 QSV 滤镜整体保留。

---

## 容器与封装

### Demuxer

保留常见输入：

```text
matroska, mov, mpegts,
h264, hevc, av1,
rawvideo, image2, concat,
aac, mp3, flac, ogg, wav
```

### Muxer

保留常见输出：

```text
matroska, mp4, mov, ipod, mpegts,
null, rawvideo, image2,
adts, flac, ogg, wav
```

### Bitstream filters

```text
h264_mp4toannexb
hevc_mp4toannexb
av1_metadata
h264_metadata
hevc_metadata
aac_adtstoasc
extract_extradata
```

---

## 示例命令

### QSV VPP 缩放 + AV1 QSV 输出

```powershell
.\ffmpeg.exe -hide_banner -y `
  -init_hw_device qsv=hw `
  -filter_hw_device hw `
  -i "input.mkv" `
  -vf "format=nv12,hwupload=extra_hw_frames=64,vpp_qsv=w=1920:h=1080" `
  -c:v av1_qsv -global_quality 34 `
  -c:a libfdk_aac -vbr 5 `
  "output.mkv"
```

### HEVC QSV 输出

```powershell
.\ffmpeg.exe -hide_banner -y `
  -init_hw_device qsv=hw `
  -filter_hw_device hw `
  -i "input.mkv" `
  -vf "format=nv12,hwupload=extra_hw_frames=64,vpp_qsv=w=1920:h=1080" `
  -c:v hevc_qsv -global_quality 28 `
  -c:a copy `
  "output.mkv"
```

### AV1 输入强制使用 libdav1d 软件解码

```powershell
.\ffmpeg.exe -hide_banner -y `
  -c:v libdav1d `
  -i "input_av1.mkv" `
  -vf "format=nv12,hwupload=extra_hw_frames=64,vpp_qsv=w=1920:h=1080" `
  -c:v av1_qsv -global_quality 34 `
  -c:a copy `
  "output.mkv"
```

### QSV 反交错 + 缩放

```powershell
.\ffmpeg.exe -hide_banner -y `
  -init_hw_device qsv=hw `
  -filter_hw_device hw `
  -i "input.ts" `
  -vf "format=nv12,hwupload=extra_hw_frames=64,deinterlace_qsv,vpp_qsv=w=1280:h=720" `
  -c:v hevc_qsv -global_quality 28 `
  -c:a copy `
  "output.mkv"
```

### 保留字幕 packet copy

```powershell
.\ffmpeg.exe -hide_banner -y `
  -i "input.mkv" `
  -map 0:v -map 0:a? -map 0:s? `
  -c:v av1_qsv -global_quality 34 `
  -c:a copy `
  -c:s copy `
  "output.mkv"
```

---

## 验证命令

```powershell
.\ffmpeg.exe -hide_banner -encoders
.\ffmpeg.exe -hide_banner -decoders
.\ffmpeg.exe -hide_banner -filters
.\ffmpeg.exe -hide_banner -hwaccels
.\ffmpeg.exe -hide_banner -demuxers
.\ffmpeg.exe -hide_banner -muxers
.\ffmpeg.exe -hide_banner -bsfs
```

关键检查：

```powershell
.\ffmpeg.exe -hide_banner -encoders | findstr /i "qsv libfdk_aac aac_at wrapped_avframe"
.\ffmpeg.exe -hide_banner -filters  | findstr /i "_qsv"
.\ffmpeg.exe -hide_banner -hwaccels | findstr /i "d3d11va dxva2"
```

不应存在的组件：

```powershell
.\ffmpeg.exe -hide_banner -filters | findstr /i "bm3d vmaf psnr ssim xpsnr nlmeans hqdn3d cuda npp opencl vulkan subtitles drawtext"
```

最后一条在本构建中应无输出，或只出现非目标误匹配项。

---

## 系统要求

| 项目      | 要求                            |
| ------- | ----------------------------- |
| OS      | Windows 10 / 11 x64           |
| GPU     | 支持 Intel QSV 的 Intel 核显 / 独显  |
| AV1 QSV | 需要支持 AV1 编码的 Intel GPU        |
| CPU     | 支持 x86-64-v3 的处理器             |
| Driver  | 建议使用较新的 Intel Graphics Driver |
| Runtime | oneVPL / Intel GPU runtime 环境 |

---


## 许可证说明

本项目脚本本身可按仓库许可证使用。

但生成的 FFmpeg 二进制会受到 FFmpeg、外部库和启用选项共同影响。
如果启用了 `--enable-gpl`、`--enable-nonfree`、`libfdk_aac` 等组件，最终二进制可能处于 `nonfree and unredistributable` 状态。

发布二进制前请自行确认许可证和再分发合规性。
如果不确定，建议只发布源码、构建脚本和构建说明，不直接发布预编译二进制。
