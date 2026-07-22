---
name: skill-creator
description: Guide for creating or updating reusable agent skills with focused instructions, optional scripts, references, assets, and validation. Use when an agent needs to create, improve, package, or validate a skill.
---

# Skill Creator

Create skills as self-contained directories that provide domain knowledge, repeatable workflows, or tool guidance.

## Structure

Every skill requires `SKILL.md`, with YAML frontmatter containing `name` and `description`.
Use optional resource directories only when they add reusable value:

```text
skill-name/
├── SKILL.md
├── scripts/       # deterministic or repeatedly needed automation
├── references/    # detailed documentation loaded only when needed
└── assets/        # templates and files used in generated output
```

Keep the main instructions concise. Put long, conditional, or domain-specific material in one-level-deep files under `references/` and link to them from `SKILL.md`.

## Workflow

1. Identify concrete requests that should trigger the skill.
2. Define the smallest reusable workflow and decide whether scripts, references, or assets are needed.
3. Initialize the directory with `scripts/init_skill.py`.
4. Write imperative instructions that state when to use each bundled resource.
5. Test any added scripts and validate the resulting skill with `scripts/quick_validate.py`.
6. For complex skills, test with realistic requests and refine the instructions from observed results.

## Writing guidance

- Make the frontmatter description explicit about what the skill does and when it should trigger.
- Prefer concise instructions and examples over background explanation.
- Match prescription to risk: use flexible guidance for judgment calls and deterministic scripts for fragile operations.
- Do not duplicate detailed material between `SKILL.md` and references.
- Do not add auxiliary documents that do not help an agent execute the skill.

## Commands

Initialize a skill:

```bash
python scripts/init_skill.py my-skill --path ./skills --resources scripts,references
```

Validate a skill:

```bash
python scripts/quick_validate.py ./skills/my-skill
```

On Windows, run Python in UTF-8 mode when validating skills containing non-ASCII text:

```powershell
$env:PYTHONUTF8 = "1"
python scripts/quick_validate.py .\skills\my-skill
```
