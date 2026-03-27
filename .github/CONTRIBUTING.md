# Contributing to Cedar & Sage Apothecary

Thank you for your interest in contributing! Please follow these guidelines to keep the project healthy.

## Branch Strategy

All work branches from and merges into **`main`**. This is the project's default and base branch.

| Branch pattern | Purpose |
|---|---|
| `main` | Stable production code — the base ref for all PRs |
| `feature/*` | New features |
| `fix/*` | Bug fixes |

> **Note for AI coding agents (Copilot, Claude, etc.):**  
> The base ref is always `main`. When creating task branches, ensure `main` exists and is checked out as the base. If you encounter `{"error":"base ref not found"}`, verify that the `main` branch exists in the remote and retry.

## How to Contribute

1. Fork the repository and clone it locally.
2. Create a branch from `main`:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/your-feature-name
   ```
3. Make your changes and commit them with clear messages.
4. Push your branch and open a pull request targeting `main`.

## Pull Request Guidelines

- Keep PRs focused on a single change.
- Fill out the PR template completely.
- Link any related issues.

## Code Style

- Follow existing code conventions.
- Run linting before committing:
  ```bash
  npm run lint
  ```
