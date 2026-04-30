# PPT Motion Kit / 高级动态 PPT 制作增强库

PPT Motion Kit 是给 OpenClaw 使用的“高级 PPT 动态感增强库”。它解决一个核心问题：用 `python-pptx` 直接生成 PPT 时，页面通常比较生硬，没有咨询公司/科技发布会那种层次、节奏和动画感。

本库的思路不是盲目堆动画，而是采用更稳定、更适合 WPS/PowerPoint 的三层方案：

1. **页面转场 Motion Transition**  
   通过 OOXML 后处理给 PPTX 添加淡入、推进、擦除等页面转场。

2. **分步构建 Build Slides**  
   不强依赖复杂对象动画，而是把一页内容拆成多个渐进页面，例如第 1 张只显示标题，第 2 张显示第一个卡片，第 3 张显示第二个卡片。播放时效果接近动画，兼容性比复杂动画更强。

3. **高级视觉组件 Cinematic Layout**  
   使用深蓝科技配色、圆角卡片、渐进式内容、章节页、指标卡、流程页、时间线页和讲述节奏，让 PPT 更像“高端产品发布/答辩汇报”，而不是普通文档堆字。

## 为什么不用纯 python-pptx 动画？

`python-pptx` 对 PowerPoint 动画支持有限。真正的对象动画需要操作复杂 OOXML timing 结构，不同 PowerPoint/WPS 版本兼容性不稳定。为了让 OpenClaw 稳定交付，本库优先采用：

- 转场动画：较稳定；
- 分步页面：最稳定；
- 层次化排版：最有效。

这也是很多正式汇报中常用的“看起来有动画，但文件非常稳”的做法。

## 安装

在 openclaw 仓库根目录执行：

```bash
python3 -m pip install --user -r ppt_motion_kit/requirements.txt
```

## 生成动态感 PPT 示例

```bash
python3 ppt_motion_kit/cinematic_builder.py \
  --spec ppt_motion_kit/examples/motion_spec.json \
  --out /mnt/c/OpenClawWork/PPT_Motion/output/motion_demo.pptx
```

输出位置：

```text
C:\OpenClawWork\PPT_Motion\output\motion_demo.pptx
```

## 给已有 PPT 添加转场

```bash
python3 ppt_motion_kit/motion_apply.py \
  --input /mnt/c/OpenClawWork/PPT_Master/output/ecg_defense_demo.pptx \
  --output /mnt/c/OpenClawWork/PPT_Master/output/ecg_defense_motion.pptx \
  --transition fade \
  --speed med
```

## 给 OpenClaw 的使用规则

把下面这段告诉 OpenClaw：

```text
以后制作高端 PPT 时，不要只生成静态页面。必须优先使用 PPT Motion Kit 的三层方案：

1. 页面结构先设计成“讲述节奏”：封面、目录、章节页、核心论点、分步展示、总结页。
2. 每页内容不要一次全出现，重要内容用 build slides 分步展示。
3. 生成后调用 ppt_motion_kit/motion_apply.py 添加统一转场。
4. 动画风格要克制：正式答辩用 fade；科技发布用 push/wipe；不要乱用夸张动画。
5. 输出文件统一放到 C:\OpenClawWork\PPT_Motion 或 C:\OpenClawWork\PPT_Master\output。
6. 完成后生成报告，说明使用了哪些动态策略。
```

## 适合场景

- 毕业答辩 PPT
- 产品发布汇报
- 科技项目展示
- Agent 自动化成果展示
- 商业计划书
- 技术路线汇报

## 推荐动态策略

| 场景 | 推荐方式 |
|---|---|
| 正式答辩 | fade 转场 + 分步卡片出现 |
| 科技发布 | push 转场 + 深蓝背景 + 指标卡 |
| 商业路演 | 章节页 + 时间线 + 关键数据渐进展示 |
| 技术路线 | flow 页面 + 每一步单独 build |
| 总结页 | 先显示结论，再显示支撑证据 |
