# Codex Skills

此目录用于收录可复用的 Codex Skills，便于版本管理与发布。本次整理新增以下两个 Skill；目录中原有的其他内容未作改动。

## 本次新增

- `auto-plan-and-execute/`：以“计划 → 评审 → 实施 → 复核”四阶段闭环执行软件需求；包含脚本、角色提示词、参考文档和 GitHub Actions 工作流。
- `prd-generator/`：协助收集信息、分析竞品并产出结构化产品需求文档（PRD）。
- `competitive-analysis/`：面向产品与市场决策的竞品分析 Skill；包含资料采集、分析框架与图表规范。

## 使用方式

将所需 Skill 目录复制或安装到 Codex 的 Skills 目录中。每个 Skill 均以 `SKILL.md` 作为入口说明；请保留其相对目录结构。

## 发布到 GitHub

```bash
cd D:\AIProject\Skills
git init
git add .
git commit -m "feat: add Codex skills"
git branch -M main
git remote add origin <你的仓库地址>
git push -u origin main
```

`auto-plan-and-execute` 已随附其原始 `LICENSE`；发布前请确认其他目录内容的来源与许可符合你的发布计划。
