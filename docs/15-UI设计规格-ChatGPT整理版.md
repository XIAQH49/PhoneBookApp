# PhoneBookApp UI 重构设计规格（ChatGPT 出稿 · 整理版）

| 项 | 内容 |
|---|---|
| 来源 | 网页版 ChatGPT 依据项目截图 + 华为运动健康参考图 + docs/12 3.1 硬约束输出，本文件整理为可直接实施的 ArkTS 设计规格 |
| 版本 | v0.1（整理版，保留全部数值；文首含「校对与修正」） |
| 设计基准 | SGT-AL10 1320×2848 竖屏；全部 vp/fp，禁止按 1320px 写死 |
| 定位 | 不是视觉方向稿，是可直接交给 ArkTS 开发的 Design Spec |

---

## ⚠ 校对与修正（开发前必读，避免照做时误改业务）

1. **设置页不要新增不存在的设置项**。ChatGPT 线框里的「自动标记已打 / 拨号后自动标记」「导入后自动筛选责任人」「外观：跟随系统/浅色/深色」**当前 App 没有**这些开关。
   - 现有设置项只有：拨号前确认、拨号前去除+86（兼容）、导出范围（当前责任人+未分配/全表）、数据信息、一键清除名单。
   - 「跟随系统」已实现（COLOR_MODE_NOT_SET），无需新增外观入口；「清除本地外呼状态」= 现有「一键清除名单」。
   - 结论：设置页只做**视觉重构**，不加新功能项、不改数据。
2. **数据模型不改**。PersonRecord/CallStatus 为 UI 层示意；本项目已用 call_list（called/connected/intention 三状态）+ raw_data 全列存储，保持 DAO/实体不动。
3. **「已打」与「打通/有意向」是三个独立状态**——保留三行独立开关，不做联动/互斥。
4. **断点 360vp**：与 docs/14 v0.1.1 勘误一致（SGT-AL10≈391vp≥360→双列，符合参考截图）。
5. **ArkUI 点击隔离**：GPT 建议 .stopPropagation()——ArkUI 无此 API。拨号 IconButton 独立 onClick 即可；若外层手势监听用 .hitTestBehavior 区分。
6. **Header 不做毛玻璃**，毛玻璃仅给 BottomActionBar。
7. **内容宽度**：平板 maxWidth=1040vp，左右 margin = max(24vp, (容器宽−1040vp)/2)。

---

## 一、设计令牌

### 1.1 色板
**Light**：bg_page #F4F6F8 / surface_card #FFFFFF / primary #0A84FF / primary_soft #E8F3FF / text_primary #17191C / text_secondary #69717D / text_tertiary #9BA3AE / success #19B46B / warning #F59E0B / danger #E84D5B / divider #E8ECF1。
**Dark**：bg_page #101214 / surface_card #1A1D21 / primary #4DA3FF / primary_soft #19324A / text_primary #F4F6F8 / text_secondary #AAB2BD / text_tertiary #737C87 / success #35D18A / warning #FFB84D / danger #FF6B78 / divider #2A3038。
资源名：app.color.bg_page / surface_card / primary / primary_soft / text_primary / text_secondary / text_tertiary / success / warning / danger / divider。
> ⚠ 不要把 Light 的 #FFFFFF 直接反相成纯黑；Dark 卡片须与页面背景形成约一层的明度差。

### 1.2 圆角
radius_card 28 / radius_feature 32 / radius_item 20 / radius_pill 999 / radius_btn 18 / radius_icon 18 / radius_search 22（vp）。大统计卡 32vp；PersonCard 24vp；搜索框 22vp；FilterChip 999vp；IconButton 直径 50vp；底部栏 28vp。**不要超过 36vp**。

### 1.3 间距
space_page 24vp（平板 32）· space_card_inner 24vp（sm 16）· space_between 12vp · space_group 24vp · space_section 32vp · space_title 8vp · space_icon_text 10vp · space_stat 20vp。平板 contentMaxWidth=1040vp。

### 1.4 字号
font_display 48fp/Bold、font_display_xl 64fp/Bold（已打数字）、font_title 32fp/Bold、font_headline 24fp/Bold（姓名）、font_body_lg 18fp/Medium（号码）、font_body 16fp/Regular、font_body_medium 16fp/Medium、font_caption 13fp/Regular、font_overline 12fp/Medium。**核心数字不用 80~96fp**。

---

## 二、组件规格
**IconButton**：50×50vp 圆 25vp，icon 24vp；主操作 primary_soft 底+primary 图标；拨号 primary 底+#FFF；按压 scale 0.92，springMotion(0.32,0.82)。不用传统 Button(拨打)。
**StatusPill**：高 34vp、paddingH 14vp；未打底 #FFF4E2 字 #E89000 点 8vp；已打底 #EAF9F1 字 #159B5A；打通底 #E8F3FF 字 #0A84FF；有意向底 #F0EBFF 字 #7657D9。点击切换无弹窗；动画 scaleX 1→1.06→1、opacity 0.85→1，springMotion(0.28,0.78)。
**FilterChips**：高 40vp、间距 8vp；选中 primary 底白字；未选中 surface_card 底+divider 描边；选中切换 scale 1→1.03→1；不用 48~52vp 宽大 chip。
**ProgressRing**：直径 156vp（平板 168），环宽 12vp；环底 #DDE1E6，进度 primary；中心 Text(0%) 32fp/Bold + Text(完成率) 14fp；startAngle=-90°，springMotion(0.65,0.86)；**不要旋转整圈动画**。
**StatCard**（首页唯一最高等级卡）：高 260vp（平板 280）；上半 170vp（左 已打 64fp / 分母，右 ProgressRing），下半三等分 已打/未打/完成率；底部「当前责任人：张三 · 共20条」（选全部责任人时显示「全部责任人 · 共128条」）。
**PersonCard**（核心组件）：双列高 190vp、padding 20vp；姓名 24fp/Bold、号码 18fp、工号 14fp；右上 StatusPill，右下拨号 IconButton 50×50vp；卡片空白点击进详情、拨号只拨号（校对 #5）。
**BottomActionBar**：高 76vp、paddingH 12vp、paddingV 8vp、圆角 28vp；left/right 20vp、底部 safeArea+16vp；平板宽 min(720vp, 容器宽−48vp)，**不占满全宽**；背景 rgba(255,255,255,0.82)+backgroundBlurStyle COMPONENT_ULTRA_THICK；4 个 icon 28vp + label 12fp；按压 scale 0.94+offsetY 1vp，responsiveSpringMotion(0.18,0.82,0.08)。

---

## 三、逐页线框

### 3.1 首页

```
┌────────────────────────────────────────────┐
│ 外呼名单                    [张三⌄] [⚙]  │
│ ┌────────────────────────────────────────┐ │
│ │ 已打                     ○──────○      │ │
│ │ 12 / 20                    60% 完成率   │ │
│ │──── 12 已打 | 8 未打 | 60% 完成率 ────│ │
│ │          当前责任人：张三 · 共20条      │ │
│ └────────────────────────────────────────┘ │
│ [🔍 搜索姓名 / 工号 / 手机]                │
│ [全部 20] [未打 8] [已打 12]               │
│ ┌──────────────┐ ┌──────────────┐        │
│ │ 客户1    未打 │ │ 客户2    未打 │        │
│ │ +86...       │ │ +86...       │        │
│ │ 工号 M310001📞│ │ 工号 M310002📞│        │
│ └──────────────┘ └──────────────┘        │
│ ┌──────────────┐ ┌──────────────┐        │
│ │ 客户3    已打 │ │ 客户4    未打 │        │
│ └──────────────┘ └──────────────┘        │
│         ╭────────────────────╮           │
│         │ ＋ 📦 📄 ↑         │           │
│         │导入 内置 原始 结果 │           │
│         ╰────────────────────╯           │
└────────────────────────────────────────────┘
```

Header：高 72vp；左「外呼名单」32fp/Bold；右「张三⌄」高 44vp/radius 22vp/primary_soft 底 + ⚙ 50vp。Header 不做毛玻璃。

### 3.2 详情页
```
┌────────────────────────────────────────────┐
│ ←     客户1                                │
│ ┌────────────────────────────────────────┐ │
│ │ 客户1 / +86-19910000001 / 国内          │ │
│ │         [ ☎ 拨打 ]（主按钮）            │ │
│ └────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────┐ │
│ │ 外呼状态：已打[ON]/打通[OFF]/有意向[OFF]│ │
│ └────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────┐ │
│ │ 客户信息：责任人/工号/手机/备注/其他列 │ │
│ └────────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```
状态卡每行高 58vp、1vp divider；Switch 约 52×32vp；三行独立，只用打开状态显示对应语义色。

### 3.3 设置页（按现有设置项，只重构视觉）
```
┌────────────────────────────────────┐
│ ←   设置                           │
│ 拨号 分组卡：拨号前确认[ON]/拨号前去除+86[ON]│
│ 导出 分组卡：当前责任人+未分配◉ / 全表○      │
│ 信息 卡片：数据 2314 条 · 名单.xlsx         │
│ 危险 卡片：⚠ 一键清除名单（danger 描边）     │
└────────────────────────────────────┘
```
> 按校对 #1：仅重构现有设置项，不新增开关。

### 3.4 责任人选择页
```
┌────────────────────────────────────┐
│ ←   选择责任人 / 🔍 搜索责任人        │
│ ● 张三  20 条任务 · 12 条已打        │
│ ○ 李四  36 条任务 · 18 条已打        │
└────────────────────────────────────┘
```
选中：primary_soft 底 + 左 8vp 蓝色指示条；行点击写配置→pop 返回（onPop 刷新不动）。

---

## 四、空间光感落地（MaterialRole + 卡片三态）
层级：背景 → normal-surface → featured-surface → floating-tool → primary-action。
- primary-action：primary 底 #FFF 字；shadowRadius 12vp/alpha 0.16/offsetY 4vp。用于拨号主按钮、选中 FilterChip、主要确认。
- floating-tool：rgba(surface,0.82)+blur ultra-thick+border rgba(255,255,255,0.55)+shadowRadius 28vp/alpha 0.12/offsetY 8vp。用于 BottomActionBar。
- featured-surface：surface_card+shadowRadius 22vp/alpha 0.08/offsetY 6vp，可加 primarySoft opacity<=0.16 极淡光（只一层）。用于 StatCard。
- selection：primary_soft 底+border primary@12%。用于选中责任人/选中 FilterChip/当前状态。
- normal-surface：surface_card+shadowRadius 16vp/alpha 0.055/offsetY 4vp。用于 PersonCard/信息卡/设置卡。
卡片三态：Default scale 1.0/offsetY 0/shadowAlpha 0.055/lightOpacity 0；Pressed scale 0.985/offsetY 1vp/shadowAlpha 0.025/lightOpacity 0.04（responsiveSpringMotion(0.16,0.88,0.06)）；Featured/Selected scale 1.0/offsetY −2vp/shadowAlpha 0.10/lightOpacity 0.08（springMotion(0.38,0.84)）。
焦点/光随指动：仅 FilterChip 选中指示（responsiveSpringMotion(0.15,0.86,0.08)）与 BottomActionBar 内选中光斑（selectionHighlightX 跟手，不整栏移动）；interpolatingSpring(velocity,1,228,30) 用于快速滑动/按压释放/底栏横向指示。

---

## 五、动效规格
5.1 首页列表进入：每卡 opacity 0→1/translateY 18vp→0/scale 0.985→1；springMotion(0.42,0.84)；错峰 i*35ms，最大 <=280ms。
5.2 筛选切换：旧卡 opacity 1→0.25/scale 1→0.985，新卡 opacity 0→1/translateY 12vp→0；优先 transition 处理插入删除，少用 animateTo 操纵布局。
5.3 StatusPill 切换：springMotion(0.30,0.80)；dot 8→10→8vp，pill scaleX 1→1.05→1；warning→success；不做闪烁。
5.4 ProgressRing：animateTo(springMotion(0.65,0.86)) 同一状态变量驱动进度与中心数字；0%→60% = 0°→216°。
5.5 BottomActionBar 按压：scale 1→0.97+shadowAlpha 0.12→0.06+offsetY 0→1vp；释放 responsiveSpringMotion(0.18,0.82,0.06)；总感知 100~180ms。
5.6 页面转场：详情 push opacity 0→1/translateX 24vp→0/scale 0.985→1，返回 translateX 0→18vp/opacity 1→0；用 TransitionEffect.OPACITY.combine(translate({x:24})).combine(scale({x:0.985,y:0.985}))，springMotion(0.42,0.86)。不做 iOS 式大幅右滑。
5.7 Hero 感（可选）：geometryTransition/sharedTransition 使 PersonCard 姓名/号码与详情头卡连续；时间紧可不做。

---

## 六、可实施性备注（关键）
6.1 颜色一律 $r(app.color.*) 资源，尤其深色（不用字面 #FFFFFF）。
6.2 毛玻璃只给浮层（BottomActionBar），不要给每张卡——否则 GPU 压力/滚动掉帧/深色脏。
6.3 主页结构：Stack > Scroll > Column(Header/StatCard/Search/FilterChips/Grid) + BottomActionBar；Grid columns = 容器宽>=360?2:1；数据源 LazyForEach 用现有 MainViewModel（Key 用行 id）。
6.4 **底栏必须给 Scroll 预留 bottomPadding = 76+24+32 = 132vp**（barHeight+safeArea+32），否则遮第二张卡（现有硬问题）。
6.5 LazyForEach key 稳定用 row.id（不用 JSON.stringify / index）；Grid 配 cacheCount 建议 8（500+ 行按真机 profile 调 8~12）。
6.6 组件状态：可观察对象 @ObjectLink、简单值 @Prop、需改状态 @Link；不要全页 @Link。
6.7 animateTo 原则：属性动画→animateTo；出现/消失→transition；跟手→responsiveSpringMotion；带速度释放→interpolatingSpring；路径→motionPath。
6.8 按压优先 scale，不要动画 width/height。
6.9 motionPath 仅 ProgressRing 装饰光点或责任人选择圆点（1 个动态节点）。

---

## 七、组件树（实现对照）
App → HomePage(Header[PageTitle/PersonSelector/IconButton(Settings)] → StatCard[DisplayNumber/ProgressRing/StatTriplet/ResponsibilitySummary] → SearchField → FilterChips → Grid[LazyForEach→PersonCard[StatusPill/PersonInfo/IconButton(Dial)]] → BottomActionBar[Import/BuiltIn/ExportOriginal/ExportResult])；DetailPage(PersonHeaderCard/CallStatusCard/InfoCard)；SettingsPage(GeneralCard/AppearanceCard/DataCard→按校对仅现有项)；PersonSelectorPage(SearchField/PersonSelectionList)。

## 八、尺寸总表（第一轮实现直接取用）
Page padding 24vp · Tablet maxWidth 1040vp · Header 72vp · PageTitle 32fp · PersonSelector 44vp · IconButton 50vp · StatCard 260~280vp · ProgressRing 156~168vp/stroke 12vp · Search 52vp · FilterChip 40vp/gap 8vp · PersonCard 190vp/padding 20vp/gap 16vp/姓名24fp/号码18fp/工号14fp · StatusPill 34vp · DialButton 50vp · BottomActionBar 76vp/radius 28vp/bottom safeArea+16vp · Scroll bottomPadding >=132vp · Card radius 24~32vp · normal shadow 16vp · featured shadow 22vp。

## 九、三个最关键视觉改造（优先做）
1. 单列大名单卡 → 双列任务网格（改善信息架构）。2. 底部四功能 → 悬浮毛玻璃工具台（让人感到是工具台）。3. 「已打 12/20 + 60%」成为首页唯一视觉主角（统计是舞台）。

## 十、别做清单
1. 别给每张 PersonCard 加蓝色发光（光感只在 StatCard/FloatingBar/PrimaryAction/Selection）。2. 别让底栏永久遮挡列表（预留 132vp）。3. 别所有动画都用弹簧（各用对应机制）。4. 别用第三方动画库（全部用 animateTo/transition/springMotion/responsiveSpringMotion/interpolatingSpring/motionPath/backgroundBlurStyle/shadow/scale-translate-opacity）。5. 别把 1320×2848 当固定设计稿（用 vp/safeArea/containerWidth/breakpoint）；唯一硬断点 <360vp→1 列、>=360vp→2 列；平板 maxWidth 1040vp。

---

> 一句话：不是把现 UI 做得更漂亮，而是把它从「所有东西都堆在一页」重构成「统计是舞台、名单是内容、底栏是工具」的空间系统。1040vp maxWidth + 360vp breakpoint + 260vp StatCard + 190vp PersonCard + 76vp FloatingBar + 24/32vp spacing 先固定，开发中各组件不要自行发挥。
