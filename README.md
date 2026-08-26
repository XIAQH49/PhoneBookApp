# PhoneBookApp（外呼名单）

内网外呼名单工具（HarmonyOS NEXT / ArkTS）：从内网导入名单文件（xlsx/csv），按责任人筛选出自己的任务，点击条目**唤起系统拨号应用并自动填入号码**（want ACTION_DIAL，**无需任何权限**），本地标记"是否已打"，按原格式导出留档。

**v0.5 新增**：内置名单——名单文件直接打包进 APP（`rawfile/名单.xlsx` 或 `名单.csv`），启动自动检测内容变化并合并导入（已打状态保留），适合内网"只能进不能出"的场景（见 `docs/08`）。

**本仓库以 SDD（Spec-Driven Development）流程开发，文档即进度：**

| 文档 | 内容 |
|---|---|
| `docs/01-需求规格说明书.md` | 需求规格 v0.2（FR-1~FR-9、NFR、7 项评审决议） |
| `docs/02-设计规格说明书.md` | 架构/数据表/流程/号码解析状态机/UI 线框 |
| `docs/03-任务清单.md` | T0~T14 任务分解 + 构建门禁 + 执行进度记录 |
| `docs/04-构建与真机调试指引.md` | CLI 构建、AGC 权限、单测说明、已知限制 |
| `docs/05-警告处置记录.md` | 编译警告逐条评估与处置（W-1~W-3） |
| `docs/06-真机验证清单.md` | T-1/T-2/T-3 spike + T14 验收清单（含性能预验证数据） |
| `docs/07-M1验收记录.md` | M1 验收结论（真机全链路通过） |
| `docs/08-v0.5-内置名单说明.md` | v0.5 内置名单（rawfile 打包名单，启动自动检测变更导入） |
| `docs/09-M2-交接与启动包.md` | 新会话无缝衔接指南 + M2 范围（警告清零/Navigation/新 API） |

## 快速验证

> 仓库内 `build-profile.json5` 的签名配置已脱敏；真机安装请在 DevEco Studio 中 Run（自动签名，首次会要求登录华为账号）。

```powershell
# 纯逻辑验证（34 项：号码解析/合并/CSV/导入准备/导出组装/xlsx 往返）
node --import ./tools/verify/register.mjs tools/verify/verify.ts

# xlsx 性能基准（2000 行）
node --import ./tools/verify/register.mjs tools/verify/perf.ts

# 编译（HAP 产物）
$env:DEVECO_SDK_HOME = 'D:\DevEco Studio\sdk'
& 'D:\DevEco Studio\tools\node\node.exe' 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.js' assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

## 目录结构（entry/src/main/ets）

```
pages/        主列表/详情/设置/责任人选择
components/   统计条/筛选/空态/选号弹层/拨号确认
viewmodel/    分页数据源（LazyForEach）
service/      导入/导出/拨号/号码解析/合并/CSV/xlsx（纯逻辑为 .ts，可 Node 直跑）
database/     RDB 四表 DAO（含双写事务）
common/       常量/日志/权限/上下文工具
model/        名单行/导入元信息/列映射
libs/         SheetJS xlsx 社区版（Apache-2.0，vendor + 手写 .d.ts）
```

## 当前状态

- ✅ **M1 完成并通过真机验收**（2026-08-25，SGT-AL10；详见 `docs/07-M1验收记录.md`）
- ✅ 核心闭环：导入(xlsx+csv)→筛选→唤起系统拨号并填号→标记→导出，0 权限、0 编译错误
- ⏭️ 后续排期：M2 警告清零与 API 迁移、M3 打通/意向列维护（见验收记录第 5 节）
