# Alex-MP

Alex's personal Claude Code plugin marketplace.

## Install

```
claude plugin install https://github.com/adimassimo/Alex-MP
```

## Plugins

- **plugin1** — Alex's personal skills, set 1
- **plugin2** — Alex's personal skills, set 2

## Adding a skill

1. Create `plugin1/skills/<skill-name>/SKILL.md`
2. Add frontmatter and content:

```markdown
---
name: my-skill
description: One line describing when to use this skill
---

# Skill content here
```

3. Bump `version` in `plugin1/.claude-plugin/plugin.json` and the matching entry in `.claude-plugin/marketplace.json`
4. Commit and push
