<#
=========================================================================
  BiliAudioFixer.ps1  -  B站音响修复工具
  ------------------------------------------------------------------
  把 B站(猫抓/各类下载器)抓下来的 m4s / mp4 音频,
  整理成手机、电脑、音响、TF卡、车载都能正常播放的文件。

  用法: 与音乐文件放在同一目录, 双击对应的 .bat 即可。
        也可在 PowerShell 里手动指定参数, 例如:
        .\BiliAudioFixer.ps1 -Mode SPK -Bitrate 256k

  参数:
    -Mode      Check(体检) / M4A / MP3 / SPK(音响专用)
    -Dir       工作目录, 默认脚本所在目录
    -Bitrate   MP3/SPK 模式的码率, 默认 MP3=320k, SPK=192k
    -Flatten   摊平到一个文件夹并编号
    -ShortName 文件名只保留序号(001.mp3), 中文名音响不认时用
    -InPlace   原地输出到当前目录, 不建子文件夹

  依赖: FFmpeg + FFprobe (需已加入 PATH)
        winget install Gyan.FFmpeg

  许可: MIT  (见 LICENSE)
  说明: 本工具只做本地文件的格式整理, 不涉及任何下载/解密行为。
        请仅用于处理你个人已拥有的内容, 勿对外分发受版权保护的音频。
=========================================================================
#>
param(
    [string]$Dir = "",
    [ValidateSet('Check','M4A','MP3','SPK')][string]$Mode = 'Check',
    [string]$Bitrate = '',
    [switch]$Flatten,
    [switch]$ShortName,
    [switch]$InPlace
)

# ---------- 0. 编码 & 环境 ----------
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
try { [Console]::InputEncoding  = [System.Text.Encoding]::UTF8 } catch { }
try { & chcp 65001 > $null 2>&1 } catch { }
$ErrorActionPreference = 'Stop'

if (-not (Get-Command ffmpeg  -ErrorAction SilentlyContinue) -or
    -not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "  [!] 没有检测到 ffmpeg / ffprobe" -ForegroundColor Red
    Write-Host ""
    Write-Host "      安装方法 (任选一种):" -ForegroundColor Yellow
    Write-Host "        1) PowerShell 里执行:   winget install Gyan.FFmpeg" -ForegroundColor White
    Write-Host "        2) 官网下载: https://www.gyan.dev/ffmpeg/builds/" -ForegroundColor White
    Write-Host "           解压后把 bin 目录加进系统 PATH" -ForegroundColor White
    Write-Host ""
    Write-Host "      装完后必须重新打开一个窗口, 否则 PATH 不生效。" -ForegroundColor Yellow
    Write-Host "      验证: 输入 ffmpeg -version 有输出即成功。" -ForegroundColor DarkGray
    Write-Host ""
    Read-Host "按回车退出"
    exit 1
}

if ($Dir -eq "") { $Dir = $PSScriptRoot }
if (-not (Test-Path $Dir)) {
    Write-Host "目录不存在: $Dir" -ForegroundColor Red
    Read-Host "按回车退出"; exit 1
}
$Dir = (Resolve-Path $Dir).Path

# ---------- 1. 默认参数 ----------
if ($Mode -eq 'SPK' -and $Bitrate -eq '') { $Bitrate = '192k' }
if ($Mode -eq 'MP3' -and $Bitrate -eq '') { $Bitrate = '320k' }
if ($Mode -eq 'SPK') { $Flatten = $true }

if ($Bitrate -ne '' -and $Bitrate -notmatch '^\d+k$') {
    Write-Host "码率格式不对, 应该写成 192k / 256k / 320k 这样的形式" -ForegroundColor Red
    Read-Host "按回车退出"; exit 1
}

# ---------- 2. 输出目录 ----------
# $hasOutDir = $false 时, 输出目录就是工作目录, 扫描时不能排除它
$hasOutDir = ($Mode -ne 'Check') -and (-not $InPlace)
if ($hasOutDir) {
    $outDir = if ($Mode -eq 'SPK') { Join-Path $Dir "音响专用" } else { Join-Path $Dir "已修复" }
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
    $outDir = (Resolve-Path $outDir).Path
} else {
    $outDir = $Dir
}

# ---------- 3. 工具函数 ----------

# 检测文件开头有没有下载器/浏览器缓存加的垃圾字节
# 返回需要跳过的字节数; -1 表示根本不是 MP4 结构
function Get-SkipBytes([string]$path) {
    $fs  = [System.IO.File]::OpenRead($path)
    $buf = New-Object byte[] 64
    $n   = $fs.Read($buf, 0, 64)
    $fs.Close()
    for ($i = 0; $i -lt 48; $i++) {
        if ($i + 8 -gt $n) { break }
        # 找 'ftyp'
        if ($buf[$i+4] -eq 102 -and $buf[$i+5] -eq 116 -and
            $buf[$i+6] -eq 121 -and $buf[$i+7] -eq 112) { return $i }
    }
    return -1
}

# 生成合法的 FAT32 文件名
function Get-SafeName([string]$s) {
    $s = $s -replace '[\\/:*?"<>|]', '_'
    $s = $s -replace '[\x00-\x1f]', ''
    $s = $s.Trim().TrimEnd('.', ' ')
    if ($s -eq "") { $s = "track" }
    return $s
}

# 从文件名提取干净的曲名 (去掉 BV号 / av号 / Pxx / audio 之类)
function Get-CleanTitle([string]$name) {
    $t = [System.IO.Path]::GetFileNameWithoutExtension($name)
    $t = $t -replace '(?i)\s*[\[\(【]?\s*BV[0-9A-Za-z]{10}\s*[\]\)】]?',''
    $t = $t -replace '(?i)\s*[\[\(【]?\s*av\d{4,}\s*[\]\)】]?',''
    $t = $t -replace '(?i)\s*[\[\(【]\s*\d{1,3}\s*[\]\)】]\s*$',''
    $t = $t -replace '(?i)_?p\d{1,3}$',''
    $t = $t -replace '(?i)\s*[-_]\s*(audio|音频|only)$',''
    $t = $t.Trim(' ', '-', '_', '.')
    if ($t -eq "") { $t = [System.IO.Path]::GetFileNameWithoutExtension($name) }
    return $t
}

# 有垃圾头就复制一份去头的临时文件, 否则返回原路径
function New-CleanSource([string]$path, [int]$skip) {
    if ($skip -le 0) { return $path }
    $tmp = Join-Path $env:TEMP ("_baf_" + [guid]::NewGuid().ToString("N") + ".m4s")
    $fs  = [System.IO.File]::OpenRead($path); $fs.Position = $skip
    $o   = [System.IO.File]::Create($tmp); $fs.CopyTo($o)
    $o.Close(); $fs.Close()
    return $tmp
}

function Remove-Temp([string]$path, [string]$orig) {
    if ($path -ne $orig -and (Test-Path $path)) { Remove-Item $path -Force }
}

# 用 ffprobe 读音频信息
function Get-AudioInfo([string]$src) {
    $raw = & ffprobe -v error -show_entries `
        "format=duration,format_name:stream=codec_type,codec_name,sample_rate,channels" `
        -of default=noprint_wrappers=1 "$src" 2>$null

    $info = @{ ok=$false; dur=0; fmt=""; acodec=""; rate=0; ch=0; hasVideo=$false }
    $lastCodec = ""
    foreach ($line in $raw) {
        if ($line -match '^duration=(.+)$')       { $info.dur    = [double]$Matches[1] }
        if ($line -match '^format_name=(.+)$')    { $info.fmt    = $Matches[1]; $info.ok = $true }
        if ($line -match '^codec_name=(.+)$')     { $lastCodec   = $Matches[1] }
        if ($line -match '^codec_type=audio$')    { $info.acodec = $lastCodec }
        if ($line -match '^codec_type=video$')    { $info.hasVideo = $true }
        if ($line -match '^sample_rate=(.+)$') {
            if ($info.rate -eq 0) { $info.rate = [int]$Matches[1] }
        }
        if ($line -match '^channels=(.+)$') {
            if ($info.ch -eq 0) { $info.ch = [int]$Matches[1] }
        }
    }
    return $info
}

# ---------- 4. 收集文件 ----------
$exts = @('.mp3','.m4s','.mp4','.m4a','.flac')
if ($hasOutDir) {
    $files = Get-ChildItem -Path $Dir -File -Recurse |
             Where-Object { $exts -contains $_.Extension.ToLower() } |
             Where-Object { -not $_.FullName.StartsWith($outDir) } |
             Sort-Object FullName
} else {
    $files = Get-ChildItem -Path $Dir -File -Recurse |
             Where-Object { $exts -contains $_.Extension.ToLower() } |
             Sort-Object FullName
}

if ($files.Count -eq 0) {
    Write-Host ""
    Write-Host "  在 $Dir 里没找到待处理文件 (支持 mp3/m4s/mp4/m4a/flac)" -ForegroundColor Yellow
    Read-Host "按回车退出"; exit 0
}

$modeName = switch ($Mode) {
    'Check' { '体检 (只读, 不修改任何文件)' }
    'M4A'   { '重封装为 .m4a  (音质零损失)' }
    'MP3'   { "转码为 .mp3  ($Bitrate)" }
    'SPK'   { "音响专用 .mp3  ($Bitrate / 44.1kHz / CBR)" }
}

Write-Host ""
Write-Host "  B站音响修复工具" -ForegroundColor Cyan
Write-Host "  目录: $Dir" -ForegroundColor DarkGray
Write-Host "  模式: $modeName" -ForegroundColor Cyan
Write-Host "  文件: $($files.Count) 个" -ForegroundColor DarkGray
Write-Host ("-" * 66)

$report = @()
$i = 0; $ok = 0; $bad = 0; $risky = 0

foreach ($f in $files) {
    $i++
    Write-Progress -Activity "处理中" -Status "$i / $($files.Count)" -PercentComplete ($i * 100 / $files.Count)

    $skip = Get-SkipBytes $f.FullName
    $src  = New-CleanSource $f.FullName $skip
    $info = Get-AudioInfo $src

    if ($skip -gt 0) { $headStrBad = "有 $skip 字节垃圾" } else { $headStrBad = "正常" }

    if (-not $info.ok) {
        Remove-Temp $src $f.FullName
        $bad++
        $report += [pscustomobject]@{
            文件名=$f.Name; 真实格式="无法识别"; 时长=""; 采样率=""
            文件头=$headStrBad; 状态="已损坏"; 建议="重新下载"
        }
        Write-Host "  [x] $($f.Name) -> 读不出来, 文件已损坏" -ForegroundColor Red
        continue
    }

    $isFake  = ($f.Extension -ieq '.mp3') -and ($info.acodec -ne 'mp3')
    $durStr  = if ($info.dur -gt 0) { [timespan]::FromSeconds($info.dur).ToString("mm\:ss") } else { "缺失" }
    $rateStr = if ($info.rate -gt 0) { "$($info.rate)Hz" } else { "?" }

    # ---------- 体检模式 ----------
    if ($Mode -eq 'Check') {
        $adv = @()
        if ($isFake)                     { $adv += "假MP3(实为 $($info.acodec)), 音响放不了" }
        if ($info.acodec -eq 'aac' -and -not $isFake) { $adv += "AAC 编码, 老音响可能不认" }
        if ($skip -gt 0)                 { $adv += "需去头" }
        if ($info.dur -le 0)             { $adv += "时长缺失, 进度条会坏" }
        if ($info.hasVideo)              { $adv += "含视频轨, 需剥离" }
        if ($info.rate -eq 48000)        { $adv += "48kHz, 部分音响需转 44.1kHz" }
        if ($adv.Count -eq 0)            { $adv += "OK" }

        $isRisky = ($adv[0] -ne "OK")
        if ($isRisky) { $risky++ }

        if ($isFake) { $stateStr = "假MP3" } else { $stateStr = "真$($info.acodec)" }

        $report += [pscustomobject]@{
            文件名=$f.Name; 真实格式="$($info.acodec)/$($info.fmt)"; 时长=$durStr
            采样率=$rateStr; 文件头=$headStrBad
            状态=$stateStr; 建议=($adv -join "、")
        }

        $c = if (-not $isRisky) { "Green" } elseif ($isFake) { "Red" } else { "Yellow" }
        Write-Host "  [$i] " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($f.Name)" -NoNewline -ForegroundColor White
        Write-Host "  $($info.acodec) $durStr $rateStr  $($adv -join '、')" -ForegroundColor $c

        Remove-Temp $src $f.FullName
        continue
    }

    # ---------- 确定输出文件名 ----------
    $base = $f.BaseName
    if ($ShortName) {
        $base = "{0:D3}" -f $i
    } elseif ($Flatten) {
        $base = ("{0:D3}_" -f $i) + (Get-SafeName (Get-CleanTitle $f.Name))
    }
    $base = Get-SafeName $base
    if ($base.Length -gt 60) { $base = $base.Substring(0, 60) }

    $ext  = if ($Mode -eq 'M4A') { ".m4a" } else { ".mp3" }
    $dest = Join-Path $outDir ($base + $ext)
    $n = 1
    while (Test-Path $dest) { $dest = Join-Path $outDir ($base + "_$n" + $ext); $n++ }

    # 源文件已经是标准 MP3, 且没有垃圾头/视频轨 -> 直接复制, 不二次转码
    if ($info.acodec -eq 'mp3' -and $skip -le 0 -and -not $info.hasVideo) {
        if ($Mode -eq 'M4A') { $dest = Join-Path $outDir ($base + ".mp3") }
        Copy-Item $f.FullName $dest -Force
        Remove-Temp $src $f.FullName
        $ok++
        Write-Host "  [$i] 复制  $($f.Name) -> $(Split-Path $dest -Leaf)" -ForegroundColor DarkGray
        continue
    }

    # ---------- 组装命令 ----------
    $title = Get-CleanTitle $f.Name
    $ff = @("-y","-hide_banner","-loglevel","error","-i",$src,"-vn")

    if ($Mode -eq 'M4A') {
        if ($info.acodec -ne 'flac') {
            # 只换容器, 音频流原封不动 -> 音质零损失
            $ff += @("-map_metadata","0","-c:a","copy","-movflags","+faststart")
        } else {
            # FLAC 塞不进 MP4 容器, 转成 AAC 保住 .m4a
            $ff += @("-map_metadata","0","-c:a","aac","-b:a","320k","-movflags","+faststart")
        }
    } elseif ($Mode -eq 'MP3') {
        $ff += @("-map_metadata","-1","-c:a","libmp3lame","-b:a",$Bitrate,
                 "-ar","44100","-ac","2","-id3v2_version","3",
                 "-metadata","title=$title")
    } else {
        # SPK: 老音响解码芯片最大兼容组合
        $ff += @("-map_metadata","-1","-c:a","libmp3lame","-b:a",$Bitrate,
                 "-ar","44100","-ac","2",
                 "-id3v2_version","3","-write_xing","1",
                 "-metadata","title=$title")
    }
    $ff += $dest

    $err = & ffmpeg $ff 2>&1
    Remove-Temp $src $f.FullName

    if (Test-Path $dest) {
        $ok++
        Write-Host "  [$i] OK    -> $(Split-Path $dest -Leaf)" -ForegroundColor Green
    } else {
        $bad++
        $msg = ($err | Out-String).Trim()
        if ($msg.Length -gt 160) { $msg = $msg.Substring(0,160) }
        Write-Host "  [$i] 失败  $($f.Name) : $msg" -ForegroundColor Red
    }
}

Write-Progress -Activity "处理中" -Completed
Write-Host ("-" * 66)

if ($Mode -eq 'Check' -and $report.Count -gt 0) {
    $csv = Join-Path $Dir "_体检报告.csv"
    $report | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
    Write-Host "  体检报告: $csv" -ForegroundColor Cyan
}

Write-Host ""
if ($Mode -eq 'Check') {
    Write-Host "  体检完成: $($files.Count) 个文件中有 $risky 个存在隐患" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  下一步:" -ForegroundColor Cyan
    Write-Host "    手机 / 电脑 / 音乐软件  ->  2_to_m4a.bat          (音质零损失)" -ForegroundColor White
    Write-Host "    音响 / TF卡 / 车载      ->  4_to_speaker_mp3.bat  (兼容性最好)" -ForegroundColor White
} else {
    Write-Host "  完成: 成功 $ok 个, 失败 $bad 个" -ForegroundColor $(if($bad -eq 0){'Green'}else{'Yellow'})
    Write-Host "  输出: $outDir" -ForegroundColor Cyan
    if ($Mode -eq 'SPK') {
        Write-Host ""
        Write-Host "  拷到 TF 卡时注意:" -ForegroundColor Yellow
        Write-Host "    - 文件放 TF 卡根目录, 别建多层文件夹 (老音响扫不到子目录)" -ForegroundColor White
        Write-Host "    - TF 卡用 FAT32 格式化 (64G 以上默认 exFAT, 多数音响不认)" -ForegroundColor White
        Write-Host "    - 拷完用「安全删除硬件」弹出, 别直接拔" -ForegroundColor White
        Write-Host "    - 单目录别超 999 首 (老音响索引上限)" -ForegroundColor White
        Write-Host "    - 中文名放不了就用 -ShortName 改成纯数字文件名" -ForegroundColor White
    }
}
Write-Host ""
Read-Host "按回车退出"
