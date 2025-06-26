# AGENTS.md

## Workflow & Merge Conflict Prevention

To ensure a clean, conflict-free repository when using Codex, GPT, or multiple contributors:

### 1. Branch Creation
- **Always create new branches from the latest `main` branch.**
- Use the following commands before starting any new task:
git fetch origin
git checkout -b feature/your-task-name origin/main

markdown
Copy
Edit

### 2. Rebasing Before PR
- **Before opening a Pull Request, always rebase your branch onto the latest `main`.**
git fetch origin
git checkout your-branch
git rebase origin/main

pgsql
Copy
Edit
- Resolve any conflicts during rebase, remove all conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`), and test the result.

### 3. Conflict Marker Check
- **Before committing or opening a PR, scan all files for conflict markers:**
grep -n "<<<<<<<\|=======\|>>>>>>>" -R .

pgsql
Copy
Edit
- If any markers are found, resolve them and clean up the code before continuing.

### 4. Pull Request & Merge Order
- **Only open or merge Pull Requests that are rebased and clean (no conflict markers).**
- **Merge PRs one at a time.**
- After merging, all remaining open branches must rebase onto the updated `main` branch before their PR can be opened or merged.

### 5. AGENT Etiquette for Parallel Work
- Multiple tasks/branches can be created in parallel.
- **Each branch/PR must independently follow all the above rules before merge.**
- If your change overlaps with a file touched by a recently merged PR, you must rebase and resolve again.

### 6. Codex/GPT Instructions
- Strictly follow these steps for every task and pull request, every time.

---

## Quick Checklist for Every PR

- [ ] Branch started from latest `main`
- [ ] Rebased onto latest `main` before PR
- [ ] No conflict markers anywhere in the files
- [ ] PR merged only after previous PRs are merged and branch is rebased

---

**Failure to follow these rules may result in your changes being rejected or overwritten.**

---

_This AGENTS.md is designed for LLM/Codex and human contributors to maintain a clean, conflict-free, collaborati
