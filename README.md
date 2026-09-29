# workbuddy-private

WorkBuddy 的**长期记忆**备份。私有仓库。

只有 `memory/` 里的内容是有价值的，其余都是脚本。

## 里面有什么

`memory/` 下每份 `<标识>-MEMORY.md` 对应 WorkBuddy 的一个记忆文件：

| 文件名 | 来自 |
|---|---|
| `global-MEMORY.md` | `~/.workbuddy/MEMORY.md` —— 跨项目长期规则 |
| `<路径>-MEMORY.md` | `<workspace>/.workbuddy/memory/MEMORY.md` —— 单个项目的长期笔记 |

`memory/MANIFEST.tsv` 两列：仓库内文件名、恢复时的绝对路径。restore 靠它定位。

## 有意不含什么

**不含 `memory/YYYY-MM-DD.md` 日志。** 日志是当日工作草稿，内容是当时的状态快照
（「设备一直离线」「已编出成品未上机」），很快就过期。长期结论已经被蒸馏进
`MEMORY.md` 和技能里了；技能在 `workbuddy-skills` 仓库。

## 重装后怎么恢复

```bash
git clone git@github.com:czghzh/workbuddy-private.git
cd workbuddy-private
./restore.sh --dry-run     # 先看会往哪儿写
./restore.sh               # 真恢复
```

- 目标文件已存在会**跳过**，不会覆盖。要覆盖先自己 `mv 目标 目标.bak`。
- 项目级记忆对应的 workspace 得先建好，`mkdir -p` 会补目录。

## 怎么同步

```bash
./sync.sh            # 收集 + 扫描 + 提交 + 推送
./sync.sh --check    # 只收集 + 扫描
```

自动发现 `~/.workbuddy/MEMORY.md` 和所有 workspace 的
`.workbuddy/memory/MEMORY.md`；workspace 被删掉后对应条目自动清掉。

推送前过一遍敏感词门禁，扫出凭据就 exit 1 停下。这个仓库虽然私有，
但门禁留着——万一哪天被设成 public，至少不至于把密码推上去。
