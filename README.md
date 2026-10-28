# 贪吃蛇 2D 🐍

基于 **Godot 4.7.2 + GDScript** 的 2D 霓虹贪吃蛇。玩法与同目录的 `godot-snake-3d`、
`flutter-snake` 保持一致，便于横向对比不同引擎、不同维度下的实际表现。

## 特性

- 六种关卡：空旷、边墙、立柱阵、十字回廊、回字迷宫、传送门
- 五种道具：加速、减速、护盾、磁铁、双倍分，HUD 显示剩余时间
- 三套配色：霓虹、糖果、经典；三种棋盘（15/20/25）与三档速度
- 平滑蛇身（Line2D 渐变 + 宽度曲线），吃食物粒子、食物点光源与环绕粒子
- 开局 3-2-1-GO 倒计时、暂停、结算、新纪录提示、最高分持久化
- 键盘与触屏滑动操作，自适应窗口尺寸

## 2D 引擎能力点

| 能力                | 位置                               | 说明                                               |
| ------------------- | ---------------------------------- | -------------------------------------------------- |
| CanvasItem 着色器   | `shaders/background.gdshader`      | 全屏流动噪点、中心辉光、暗角与胶片颗粒             |
| Line2D              | `scripts/snake_view.gd`            | 渐变 + 锥度蛇身、圆角关节；传送时拆成多段折线      |
| 自定义绘制          | `scripts/board_view.gd`            | 棋盘格、网格、墙体、边框与四角装饰，仅在换色时重绘 |
| 自定义绘制          | `scripts/food_view.gd`             | 六种食物/道具形状、呼吸光环，全部为矢量绘制        |
| GPUParticles2D      | `scripts/game.gd` `_burst`         | 吃食物爆发、死亡爆散，颜色随道具变化               |
| PointLight2D        | `scripts/food_view.gd`             | 食物点光源照亮棋盘；食物自身设为 unshaded 防过曝   |
| Tween               | `scripts/hud.gd` `scripts/game.gd` | 倒计时弹跳、分数飘字、死亡闪屏                     |
| Camera2D + 容器锚点 | `scripts/game.gd` `scripts/hud.gd` | 按窗口与棋盘尺寸计算缩放；HUD 全屏自适应           |
| 运行时音频合成      | `scripts/synth.gd`                 | 用 GDScript 生成 PCM，音效与循环 BGM 零素材依赖    |

## 操作

| 操作       | 按键 / 手势                         |
| ---------- | ----------------------------------- |
| 转向       | 方向键 / WASD，或按住鼠标左键滑动   |
| 暂停、继续 | 空格 / Esc，或点击右上角「暂停」    |
| 重开       | R（游戏中）或回车（菜单、结算界面） |
| 静音       | M，或点击「音效」按钮               |
| 开始游戏   | 回车，或点击「开始游戏」            |

## 运行

需要 Godot **4.7.2**（标准版即可，无需 .NET）。用项目管理器导入
`project.godot`，按 F5 运行；也可以直接命令行启动：

```bash
godot --path .
```

渲染器为 `gl_compatibility`，2D 光照、着色器与粒子都可在该渲染器下工作，
同时兼容较老显卡与驱动。

## 测试

无头冒烟测试覆盖关卡生成、吃食物、道具、护盾、传送门、暂停、重开与音频合成：

```bash
godot --headless --path . res://tests/smoke_test.tscn
```

测试场景为 `tests/smoke_test.tscn`，共 59 项断言，退出码非 0 表示失败。

## 导出

`export_presets.cfg` 包含两个预设：

- **Windows Desktop** → `build/windows/Snake2D.exe`（内嵌 PCK，单文件）
- **Web** → `build/web/index.html`（单线程，可静态托管）

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/Snake2D.exe
godot --headless --path . --export-release "Web" build/web/index.html
```

导出前需要安装对应版本的导出模板。Web 构建还需要中文字体子集
`assets/fonts/web_cjk.otf`：CI 会在构建时临时生成（不入库），本地可执行
`python tools/subset_web_font.py` 生成；否则 Web 页面中文会回退为方框。

推送 `v*` tag 或手动触发工作流后，CI 会把 Web 产物发布到 `gh-pages` 分支
（首次使用需在仓库 Settings → Pages 中选择该分支）。

## 目录结构

```text
.
├── scenes/main.tscn      # 主场景：棋盘、食物、蛇、相机、HUD
├── scripts/
│   ├── board_logic.gd    # 纯逻辑：关卡布局、出生点、随机空格
│   ├── board_view.gd     # 棋盘静态绘制
│   ├── portal_layer.gd   # 传送门动画
│   ├── snake_view.gd     # Line2D 蛇身与蛇头
│   ├── food_view.gd      # 食物绘制、灯光与粒子
│   ├── hud.gd            # HUD、菜单、暂停、结算
│   ├── game.gd           # 状态机、网格推进、输入、特效
│   ├── palette.gd        # 三套配色
│   ├── synth.gd          # PCM 合成
│   ├── sfx.gd            # 音效播放器池（Autoload）
│   └── save_data.gd      # 配置与最高分（Autoload）
├── shaders/background.gdshader
├── tests/smoke_test.tscn
└── tools/subset_web_font.py   # 生成 Web 中文字体子集（CI 使用）
```

## 玩法参数

与 Flutter 版 `flutter-snake` 对齐：

| 项           | 值                                             |
| ------------ | ---------------------------------------------- |
| 棋盘尺寸     | 15×15 / 20×20 / 25×25，默认 20×20              |
| 步进间隔     | 300 / 200 / 100 ms，默认 200 ms                |
| 得分         | 普通食物 +10，双倍分期间 +20                   |
| 道具持续时间 | 加速 6s、减速 5s、护盾 10s、磁铁 6s、双倍 8s   |
| 道具出现概率 | 28%                                            |
| 加速 / 减速  | 步进间隔 ×0.65 / ×1.5（下限 60ms、上限 600ms） |

## 字体

桌面端不自带字体文件，由 `scripts/ui_font.gd` 通过 `SystemFont` 读取系统字体：
Windows 微软雅黑、macOS 苹方、Linux 思源黑体/文泉驿，最后回退到 `sans-serif`。
仓库因此不含字体二进制，克隆体积更小。

Web 端无法访问系统字体，CI 导出前会下载 Noto Sans SC，并按界面实际出现的字符
裁剪成子集 `assets/fonts/web_cjk.otf`（通常几百 KB，不入库），再打进 Web 构建；
`tools/subset_web_font.py` 可在本地复现这一步。

## 许可证

MIT
