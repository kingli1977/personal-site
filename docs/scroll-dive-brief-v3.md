# 水下下潜 Demo 任务书 v3.0（Seascape 移植版）

## 〇、背景：为什么有 v3.0

v2.x 自研海面虽数值达标，但用户终审判定"一眼塑料感，与原视频真海水差距巨大"。根因确诊：自研 Blinn-Phong 高光（`pow(N·H,140)` 均匀镜面反光=塑料签名）与真实海水渲染差距是参数手艺问题，自研路线收敛成本过高。

决定放弃自研，改走移植路线。参照作 gyut.cn 的海面算法（拆源码确认）即 Shadertoy 上 TDM 的 **Seascape**（shadertoy.com/view/Ms2SD1）直系。本轮把 Seascape 的海面渲染原码移植进现有工程，替换自研海面段。

## 一、移植来源与授权（必须遵守）

- 源码：TDM "Seascape"，shadertoy.com/view/Ms2SD1（GitHub 镜像 tdmaav/shadertoy/Seascape.shader，204 行）
- 授权：Shadertoy 默认 **CC BY-NC-SA 3.0**——非商业可用、须署名、衍生同许可
- 义务（三样都要做）：
  1. frag.glsl 文件顶部加注释：`// Sea height field, tracing & shading adapted from "Seascape" by TDM — https://www.shadertoy.com/view/Ms2SD1 — CC BY-NC-SA 3.0`
  2. 页面 footer 或 README 一行署名：Ocean rendering adapted from "Seascape" by TDM (CC BY-NC-SA 3.0)
  3. 本项目衍生部分继续按 CC BY-NC-SA 共享（个人非商业站点，合规）
- 换掉的自研代码直接删除，不留死代码

## 二、移植范围（只换海面段，其余不动）

**替换**（frag.glsl 内）：
- `seaHeight / choppy / rot`（自研波场）→ Seascape 的 `sea_octave + map + map_detailed`（含 SEA_HEIGHT=0.6 / CHOPPY=4.0 / SPEED=0.8 / FREQ=0.16 原参数起步）
- `traceSea`（自研求交）→ `heightMapTracing`（含 NUM_STEPS=32 二分求交）
- `seaNormal` → `getNormal`（含 eps 按距离衰减）
- `shadeSea` → `getSeaColor`（含 diffuse(…) 柔和漫反射、specular(…) 高光、高度衰减颜色 `p.y - seaHeight`、天空反射）
- `skyGradient/skyColor/reflectedSky` → `getSkyColor`（Seascape 原版天空）

**保留**（工程已验收过的部分，一行不改）：
- main.js 全部（滚动→uDepth、?at= 直达、Watch the film、adaptScale 自适应、reduced-motion）
- 水下段 `underwater()` 及其暗青蓝能量档（v2.1 已校准达标：45% p99≤70 / R/B≤0.22）
- 水线 waterline()、暗角、gamma、地平线照片混合、文案层与浅色底深蓝字方案
- index.html / styles.css 结构

**衔接点**（v2.1 已定的调用约定照旧）：
- 海面段入口仍由 rd.y 分支与 mask 门控
- Seascape 的 ori/dir/time 从现有相机体系取值（camY 1.10→0.14、鼠标视差、SEA_TIME = 1.0 + uTime*0.8）
- getSkyColor 的太阳高度调到日落位（l = normalize(vec3(0.28, 0.015, 0.96))，与 v2.1 一致）
- 移植后按 v2.1 验收带微调常量：45% 水下 p99 ≤ 70、R/B ≤ 0.22、90% p99 ≤ 60 不得回退

## 三、WebGL1 兼容改造（Seascape 是桌面 GLSL，进网页必须做）

- `texture` → `texture2D`；`in/out` → `varying`；删掉 `iTime/iChannel` 声明，改用现有 uniforms（uTime/uDepth/uMouse/uResolution/uHorizon/uHasPhoto）
- Seascape 里 `mat2(1.6,1.2,-1.2,1.6)` 等构造照搬即可（WebGL1 GLSL ES 1.0 兼容）
- 保留 mediump 降级与 precision 头

## 四、验收标准（交付前自检并附数值）

1. **海面真实感（本轮核心）**：2% 进度截图的**中带（海面）细节梯度 ≥ 2.0 且高光分布非均匀**（Seascape 特征：波峰锐利+波谷柔和+太阳耀斑随波统计闪烁）；自检同时录 8-10s 海面段视频帧序，逐帧太阳耀斑位置/强度应有变化
2. 45% 水下：全屏 L p50 ≤ 35、p99 ≤ 70、R/B ≤ 0.22（不得回退）
3. 90% 深水：p99 ≤ 60、R/B ≤ 0.22（不得回退）
4. 2% 顶带 R/B ≤ 0.7（不得回退）
5. 性能：桌面 Chrome ≥50fps（adaptScale 兜底仍在）
6. 署名注释与 footer 署名存在（grep 可查）
7. PR #3 新 commit；预览链接 200

## 五、汇报格式

只报：改动文件清单 + 每项验收实测值 vs 目标值 + 预览链接。禁自评"已达标"。
