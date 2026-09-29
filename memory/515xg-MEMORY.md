# 515xg 项目长期笔记（索引级；细节全在技能里）

设备 **ZNXT ZN515XG-D**（Airoha AN7581，XG-PON，aarch64/musl，apk 3），**两台同型号**。
源码树 `/home/wen/515xg/ponwrt`（`czghzh/ponwrt`，ImmortalWrt 派生，target `airoha/an7581`）。
- ⚠️ **2026-09-29 22:10 起整棵树移到了外接 USB SSD**：`/home/wen/515xg` 是**软链**，指向盘上的 `515xg` 子树
  ⇒ 写死的绝对路径照常可用，但**盘没挂上时软链是悬空的**（命令会响亮报 No such file，不会静默写回系统盘）。
- 🔴 **2026-09-30 00:43 掉过盘**：原 `devid 1 /dev/sdb1` 变 **MISSING**（read_io_errs 1210）⇒ 挂载点变**死挂载**
  （`ls` 还列得出名字，`cat` 直接失败）。重插后枚举成 **`/dev/sdc1`**，卷 UUID **`c8e63b43-ceb0-4f97-a2e2-0cb2f4028bb0`**
  （≠ 原盘 `38838507-…`；是 `btrfs send/receive` 型克隆：UUID 新、**FS bytes used 48.31 GiB 与原盘完全一致**），
  被 udisks2 挂到 **`/media/wen/38838507-…baf1`**（带尾巴 1）、rw。老 `…baf` 的死挂载**没清**（实测不卡：`ls`/`df` 都 rc=0）。
- ✅ **换盘正确姿势（2026-09-30 定）：`ln -sfn <新挂载点>/515xg /home/wen/515xg`** —— 不用 sudo、不动挂载。
  依据：`staging_dir` 里 **3717 个文件烘焙的是逻辑路径 `/home/wen/515xg/ponwrt/…`，含 `/media/…` 的 0 个**
  （旧构建时 `/home/wen/515xg` 是物理挂载点，`getcwd()` 给出的就是它）。make 走软链、用逻辑路径 ⇒ 换盘不破坏烘焙路径。
  **⇒ 别用 bind mount 代替软链**：不持久，重启后只剩空目录，工作区会「看起来全空」。
  ⚠️ 但 `getcwd()` 会解析软链 ⇒ 现在 TOPDIR 是 `…baf1/…`，新写出的 `staging_dir` 文件会带物理路径；
  两种前缀都指向同一批文件（都能解析）⇒ **功能无害**，别再纠结。
  （另一份 `/home/wen/515xg-src-old/ponwrt` **不是**能用的编译树：`build_dir/target-*` 空的。）
  该盘走 **USB3**（Fanxiang S100Pro 256G，JMicron JMS578 桥），靠 **udisks2 自动挂载**（依赖用户会话，纯 SSH 无图形会话开机可能没挂）。
  不能 `btrfs device add` 并入系统盘：USB 盘一掉，`@`/`@home` 同属这个缺设备的 btrfs ⇒ 开不了机。
  迁入后系统盘 `/home` 可用 15G→46G；旧副本删掉了可再生的 `build_dir`(42G)，剩余约 7.8G 兜底留在 `/home/wen/515xg-src-old`。
  ⇒ 在这个 USB 盘上全量重编比 NVMe 慢（估 1.5–2 倍），增量编译受影响小。
- **设备地址 = `192.168.1.1`**（设备自身 `br-lan = 192.168.1.1/24`）；宿主机 **wifi `wlp59s0 = 192.168.1.210/24`**，
  默认网关就是它。⚠️ **2026-09-30 纠正**：旧笔记里的「16.1 / `192.168.16.1`」**探不通**（SSH 超时，宿主机也不在 16 网段），
  我照旧笔记去探，结果误判过「设备离线」——**以 `192.168.1.1` 为准**；`192.168.16.1` 那条存疑，未再复现。
  另一条旧笔记「宿主机上 `192.168.1.1 via …` 是失效历史路由」**也已作废**：现在它就是默认网关。
- 设备实测（2026-09-30）：`PonWrt SNAPSHOT r41435-7cf7bd0e2a`、内核 6.18.52、hostname `ponwrt`、
  **内存 422 MiB**、无 swap、`/overlay` = `/dev/ubi0_5`（159 MiB，**已无 extroot / 无 /mnt/sda1**）、
  `/www/kmods` 1193 apk、已装 248 包、WAN = `pppoe-wan 172.20.48.8`（通）。三项固件默认项实测生效。
- ⚠️ 设备**没装 `sftp-server`**（dropbear）⇒ `scp` 报 `sftp-server: not found`；传文件用
  `ssh root@192.168.1.1 'cat > /tmp/x' < 本地文件`。

**先探测再信**；密钥变过 ⇒ 加 `-o StrictHostKeyChecking=no`；⚠️ 设备 shell 是 **busybox ash 无 bash** ⇒ 多行脚本用 `sh -s`。

## 铁律（最高优先级）
1. 命令**进宿主机**执行（`debian`）；root：`printf "\n" | sudo -S -p "" <cmd>`（wen 空密码）。
2. **编译/构建必须在宿主机**，**开编前先问用户**。3. **刷机等用户明确说"刷"**。4. **有疑问不猜先交通**；**实话优先**。

## 跑 make 前：净化「删除外壳」
WorkBuddy 把 `shim/safe-bin`（`rm` 走回收站）塞进 `PATH` ⇒ `/bin/sh -c` 里的 make `rm` 失败即非 0 ⇒ 构建崩。
**三行净化命令见用户级 `~/.workbuddy/MEMORY.md`**；删大目录用 `/bin/rm -rf`（绝对路径，绕开 `PATH` 里的外壳）。

## ⚠️ 本快照的增量编译**不幂等**（2026-09-30 查清根因，别再瞎试）
`include/package.mk:264` 是 `$(STAMP_BUILT): $(STAMP_CONFIGURED) $(STAMP_BUILT_DEPENDS)`，
规则体第一句 `rm -f $$@; touch $$@_check` ⇒ 一判定过期就删掉 `.built` 重编。
而 **`$(PKG_BUILD_DIR)/.dep_files` 在每次 make 的末尾被重写**，mtime 永远晚于 `.built`（实测 iwinfo：
`.built` 00:55:06 / `.dep_files` 00:59:11）⇒ **下一轮永远判「脏」⇒ 死循环，settle 不了**。
表现：单包 `compile` 每次重编 9~14 个包、多花约 43 s；apk 每次重打（14107→14105→14103 B）。
**无功能性影响**（门禁仍 PASS=35/FAIL=0），但 **apk 不可字节级复现 ⇒ 验收别只看 sha256**。
⇒ 别再试「跑一次全量 make 就安静了」；要根治得改上游 `package.mk` 的写入时机，风险大于收益。

## ⚠️ 头号坑：`=m` 的包「编出来但不进镜像」，不报错
`configs/an7581.config` 显式 `CONFIG_PACKAGE_xxx=m` 压过 `default y if DEFAULT_xxx`（09-27 实测缺 14 个）。
修法/验收 + 构建踩点（绝不 `rm -f */Image`、改 `files/` 要删 `root-airoha`+`.package_install`、
`Image`≈14 MB/BTF 后≈20 MB、**mt7996 家族 7 包必须显式 not set 否则变砖**、门禁 `--expect-kmods-dir`
填 **apk 个数**）见技能 **`openwrt-offline-kmod-repo`**。

## daed 内核能力 —— 已闭环（09-29 16.1 实测）
`CONFIG_XDP_SOCKETS` 是 **bool** ⇒ 一开就变 vermagic ⇒ **1192 kmod 全量重打**，省不掉。开齐 9 项
（`KERNEL_{PERF_EVENTS,FTRACE,KPROBES,KPROBE_EVENTS,BPF_EVENTS,BPF_STREAM_PARSER,XDP_SOCKETS,
DEBUG_INFO_BTF}=y` + `# KERNEL_DEBUG_INFO_REDUCED is not set`，16 行 diff）；`daed`/geo **在线可装不用编**。
设备上 daed 全家 + `kmod-xdp-sockets-diag` + `cls_bpf`(8 refs) 实测 running；⚠️ `xdp_diag` 未加载**正常**（按需）。
退化检查法与索引签名见技能。

## 出厂数据 / 交付
- `factory` 分区 `reservearea.bin`（MAC/PON SN/光模块校准）已备份，**绝不能动**。
  ⚠️ 09-29 发现它**唯一一份副本躺在回收站里**（全盘无第二份），已救回
  `/home/wen/mtd_bak/reservearea.bin`（2,359,296 B，sha256 `3bbf1fab1653…b231b0572`，两份校验一致）。
  ⇒**清回收站前先确认它已经在外头**，别手滑把 factory 备份清掉。
- 镜像 `/home/wen/sysupgrade-ponwrt-515xg-<日期>-<时间>.itb`（+`.manifest`/`.build.log`）；说明 `/home/wen/515xg-ponwrt-交付说明.md`。
- **当前交付 `…-20260929-0412.itb`**：67,350,793 B、**237 包**、sha256 `d96c41fd…`；= 0338 基础「固件默认项三改」，**内核与 0338 逐字节相同**。历史：`0338`(238 包/`4ebeecf0…`, vermagic `6b20101949d90311238971be352f0c1a`)、`0105`(`6d668346…`) 备查；**0828 作废**。
- **16.1 已刷 0412**：`/www/kmods`=**1193 apk 含 `kmod-xdp-sockets-diag`**；与 manifest 比"缺 0、多 13"。
- ⚠️ **判版本别看 mtime**（`SOURCE_DATE_EPOCH` ⇒ 文件 mtime=最近 commit 时间）；判据=「本版新增文件在不在」+ 与 manifest 逐包比对（先规范化 `name-version`）。

## 固件默认项（0412 定稿）：主题 / country / 5G 宽度
**LuCI 主题=bootstrap**（argon 删包即可）、**country=CN**（新增 `target/linux/airoha/base-files/etc/board.d/04_wifi`:`ucidef_set_country CN`；覆盖优先级 `04_wifi`→`05_fw_defaults`，本机无 `/etc/fw_env.config` ⇒ CN 稳）、**5G=160 MHz**（改 `mac80211.uc:59` 的 `>80→80` 为 `>160→160`）。**CN 域 160MHz 只有 36–64**（`(5725-5850 @ 80)`），改 149+ 会静默掉回 HE80。⚠️ 改包内 `files/` 必须 clean 再编；`/etc/config/wireless` 只在首次生成 ⇒ 保留配置刷机 country/htmode **不会变**。硬件 **MT7916**（PCIe1 `14c3:7906`，band0=2.4G/band1=5G）。细节见 `openwrt-firmware-defaults`。

## 状态总览「卡片」—— 独立 apk
主页已还原源码默认；卡片由包 **`package/emortal/luci-app-zn515xg-hw`** 提供（`.config` 里 `=m` ⇒ 只编 apk 不装镜像）。
机制：总览 include **运行时扫目录** ⇒ 新文件名自动加载；默认块靠包脚本**改名** `.disabled` 停用。

- **r2（2026-09-30）· 已编出成品、未上机**：`15_hw.js` 改成「左 2×2 四卡 + 右硬件信息（3:2，窄屏自动堆叠）」；
  新增 `22_memstore.js`（「内存与储存」合并块、内部并排卡片）⇒ 现在一轮接管 **三个** stock 块
  `10_system` / `20_memory` / `25_storage`。权威仓库 `/home/wen/luci-app-zn515xg-hw` 已提交 `e3528b4`
  （**按用户意思未推 GitHub**）。预览 `/home/wen/515xg-homepage-mod/preview.html`。
- **成品固化在 `/home/wen/515xg/out/luci-app-zn515xg-hw-1.0.0-r2.apk`**（14103 B、sha256 `a140ea93…`）——
  构建树里那份每编一次就被重打，**别用它**。门禁 `bash /home/wen/515xg-homepage-mod/verify-pkg.sh <apk>` = **PASS=35/FAIL=0**。
- ⚠️ 装完**必须重登 LuCI**，并清 `/tmp/luci-indexcache`、`/tmp/luci-modulecache`。签名：跑谁固件带谁钥匙。
- **16.1 现跑 0412 ⇒ 卡片包没装**（要手动推）；**设备 2026-09-30 00:4x 起一直离线**（`192.168.16.1` SSH 超时），
  r2 尚未上机验证。上机后跑 `post-flash-check.sh <IP>` 体检（其 6 个期望 sha256 已与包内文件对齐）。
  细节见 `luci-block-overlay-customize`。

## 源码仓库同步（GitHub）
`origin` = **SSH `git@github.com:czghzh/ponwrt.git`**。09-29 推 `7cf7bd0e2a..eff766bc16`（4 commit，ff）⇒ 远端 `master=eff766bc16c1fd7e68cda465de26edc4ed8a2eb3`。提交风格 **英文 + `子系统: 描述`**，身份 `czghzh <…@users.noreply.github.com>`。有意不推：顶层 `files/`（49 MB kmod 仓库）、`.config`、`build_dir`/`staging_dir`/`bin`。

## 硬件卸载（详见技能 `airoha-hw-offload-verify`）
这棵树上**双向都卸载**。09-29 新增两条硬结论：
- **代理流量（daed/任何本地终结）永远不卸载**：tc/eBPF `bpf_redirect` 进 netns `daens` 本地终结，**从不进 forward 链**；铁证 `ip netns exec daens wc -l </proc/net/nf_conntrack` = **0**。换 sing-box/mihomo/xray（nft tproxy）同样无效。hy2 = 用户态加解密/拥塞控制 ⇒ 占设备 CPU ≈70%。唯一出路：**代理外置到有线接入的另一台机器**。
- **无线客户端双向都不进 FOE**：`airoha_ppe_get_wdma_info()` 要 `DEV_PATH_MTK_WDMA`，注册者**只有 `mt7996/pci.c`**；mt7915 无 NPU 宏 ⇒ `dev_fill_forward_path()` 返回 `-EOPNOTSUPP` → `-EINVAL`。**改配置/重编译无解**，不是配置关的。
- ⚠️ `ppe/bind` 的 `packets/bytes` **恒 0 不能当判据**；`npu_attached` 是**懒挂载**。
- 省 CPU 实测：代理每 GB 系统 CPU 是直连 **2.5 倍**（daed 占 71.7%）；`bandwidth_max_rx` 1gbps→200mbps 吞吐 **+13%**/CPU **-6%**，再 +`log_level:warn`+`udphop_interval:10m` 累计吞吐 **+25%**；中断亲和无收益。文档 `/home/wen/515xg/hw-offload-diag/{proxy-offload-诊断,measure-results}-20260929.md`。
