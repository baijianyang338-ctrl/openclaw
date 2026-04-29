# PPT Final Kit / 高端 PPT 自动制作库

PPT Final Kit 是给 OpenClaw 安装到电脑里使用的 PPT 自动化代码库。它的目标不是生成普通幻灯片，而是把“需求理解、结构设计、视觉规范、自动排版、交付检查”做成一个稳定工作流。

## 学习来源与设计吸收

我参考了开源社区常见 PPT 自动化项目的工程思路，例如：

- `python-pptx` 生态：用 Python 生成可编辑 PPTX，而不是只导出图片。
- AI PowerPoint Generator 类项目：把主题、大纲、逐页内容转成结构化页面。
- 商业咨询 PPT 方法：封面、目录、章节页、结论先行、卡片式布局、关键数据可视化。
- 前端组件化思想：把标题、卡片、流程图、时间线、指标块、结尾页封装成可复用组件。

本库不复制前辈代码，而是重新实现一个更适合 OpenClaw 的本地自动化版本。

## 能力目标

- 根据 JSON 需求文件生成正式、干净、专业的 PPT。
- 统一浅色背景、顶部色条、圆角卡片、深蓝 + 蓝色强调配色。
- 支持封面、目录、章节页、双栏内容、流程图、指标卡、时间线、总结页、致谢页。
- 生成后输出质量检查报告，指出页数、主题、风险和改进建议。
- 后续可接入 OpenClaw：让 Agent 先写 spec，再调用本库生成 PPT。

## 安装

```bash
cd openclaw
python -m pip install -r ppt_final_kit/requirements.txt
```

## 快速测试

```bash
python ppt_final_kit/ppt_master.py --spec ppt_final_kit/examples/ecg_defense.json --out /mnt/c/OpenClawWork/PPT_Master/output/ecg_defense_demo.pptx
```

Windows 路径：

```text
C:\OpenClawWork\PPT_Master\output\ecg_defense_demo.pptx
```

## 给 OpenClaw 的指令

```text
请安装并测试 ppt_final_kit。
1. 进入 openclaw 仓库目录。
2. 执行 python -m pip install -r ppt_final_kit/requirements.txt
3. 执行 python ppt_final_kit/ppt_master.py --spec ppt_final_kit/examples/ecg_defense.json --out /mnt/c/OpenClawWork/PPT_Master/output/ecg_defense_demo.pptx
4. 打开输出目录，确认 PPT 可以用 WPS 或 PowerPoint 打开。
5. 生成一份测试报告，说明页数、主题、输出路径和下一步升级建议。
```

## 使用方式

以后让 OpenClaw 做 PPT 时，不要直接让它写代码，而是让它先生成一个 spec：

```text
请先按 ppt_final_kit 的 JSON 结构生成 PPT 需求文件，再调用 ppt_master.py 生成 PPTX。要求：正式、浅色背景、深蓝主色、圆角卡片、顶部色条、每页有明确标题和讲述逻辑。
```
