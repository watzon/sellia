# Contribution Workflow

This document outlines the complete workflow for contributing to Sellia, from forking to merging.

## Table of Contents

- [Getting Started](#getting-started)
- [Setting Up Your Fork](#setting-up-your-fork)
- [Branching Strategy](#branching-strategy)
- [Making Changes](#making-changes)
- [Submitting a Pull Request](#submitting-a-pull-request)
- [Code Review Process](#code-review-process)
- [Addressing Feedback](#addressing-feedback)

## Getting Started

### Prerequisites

Before contributing, ensure you have:
- [Read and understood the Code of Conduct](#code-of-conduct)
- [Set up the development environment](../development/)
- [Familiarized yourself with the codebase](../project-structure/)
- [Reviewed the code style guidelines](code-style.md)

### Create Your Fork

1. **Fork the repository**
   - Go to [github.com/watzon/sellia](https://github.com/watzon/sellia)
   - Click the "Fork" button in the top-right corner
   - Choose your GitHub account as the destination

2. **Clone your fork locally**

```bash
git clone https://github.com/YOUR_USERNAME/sellia.git
cd sellia
```

## Setting Up Your Fork

### Add Upstream Remote

Add the original repository as an upstream remote to keep your fork synchronized:

```bash
cd sellia
git remote add upstream https://github.com/watzon/sellia.git

# Verify remotes
git remote -v
# Should show:
# origin    https://github.com/YOUR_USERNAME/sellia.git (fetch)
# origin    https://github.com/YOUR_USERNAME/sellia.git (push)
# upstream  https://github.com/watzon/sellia.git (fetch)
# upstream  https://github.com/watzon/sellia.git (push)
```

### Install Dependencies

```bash
# Install Crystal dependencies
shards install

# Install inspector UI dependencies
cd web && npm install && cd ..

# Build the project
shards build

# Run tests to verify setup
crystal spec
```

### Configure Git

Ensure your git identity is configured:

```bash
git config user.name "Your Name"
git config user.email "your-email@example.com"
```

## Branching Strategy

### Main Branch

- **`main`**: The stable, production-ready branch
- Protected from direct pushes
- All changes go through pull requests

### Your Branches

Create branches from `main` for your work:

```bash
# Ensure your main is up to date
git checkout main
git fetch upstream
git rebase upstream/main

# Create a new branch for your work
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### Branch Naming Conventions

Use descriptive branch names:

- `feature/add-tcp-tunnels` - New features
- `fix/websocket-timeout` - Bug fixes
- `docs/update-api-guide` - Documentation updates
- `refactor/tunnel-registry` - Code refactoring
- `test/add-protocol-tests` - Adding tests
- `chore/update-dependencies` - Maintenance tasks

## Making Changes

### 1. Make Your Changes

Edit files and implement your feature or fix.

### 2. Follow Code Style

Ensure your code follows the [code style guidelines](code-style.md):

```bash
# Format Crystal code
crystal tool format ./src

# Check formatting (CI will check this)
crystal tool format --check ./src
```

### 3. Write Tests

Add tests for new functionality or bug fixes:

```bash
# Run tests
crystal spec

# Run specific test file
crystal spec spec/core/protocol/message_spec.cr
```

### 4. Test Your Changes

Test locally before pushing:

```bash
# Run full test suite
crystal spec

# Build the project
shards build

# Test manually if applicable
./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io
```

### 5. Commit Your Changes

Use [conventional commits](commit-messages.md):

```bash
# Stage changes
git add .

# Commit with conventional commit message
git commit -m "feat(cli): add custom timeout flag for connections"
```

Example commits:
```bash
# Feature
git commit -m "feat(cli): add --timeout flag for connection timeout"

# Bug fix
git commit -m "fix(server): handle WebSocket close during request processing"

# Documentation
git commit -m "docs: update installation instructions for macOS"

# Test
git commit -m "test(core): add protocol message serialization tests"

# Refactor
git commit -m "refactor(server): simplify tunnel registry logic"
```

### 6. Sync with Upstream

Keep your branch up to date with upstream:

```bash
# Fetch upstream changes
git fetch upstream

# Rebase your branch on top of upstream/main
git rebase upstream/main

# If there are conflicts, resolve them and continue:
# Edit files to resolve conflicts
git add <resolved-files>
git rebase --continue
```

### 7. Push to Your Fork

Push your branch to your fork:

```bash
git push origin feature/your-feature-name
```

For force pushing after rebasing (careful!):

```bash
git push origin feature/your-feature-name --force-with-lease
```

## Submitting a Pull Request

### 1. Create Pull Request

- Go to your fork on GitHub
- Click "Compare & pull request" next to your branch
- Or go to "Pull requests" → "New pull request"

### 2. Fill in the PR Template

GitHub will provide a template. Fill in:

**Title:**
```
feat(cli): add custom timeout flag for connections
```

**Description:**
```markdown
## Summary
- Add `--timeout` flag to CLI for custom connection timeout
- Default timeout is 30 seconds
- Closes #123

## Changes
- Added timeout parameter to CLI options
- Updated tunnel client to use custom timeout
- Added tests for timeout handling

## Test Plan
- [x] Unit tests pass
- [x] Manual testing with various timeout values
- [x] Tested with `--timeout 5` and `--timeout 60`
```

### 3. Link Issues

Reference related issues:

```markdown
Closes #123
Fixes #456
Related to #789
```

### 4. Request Review

- Request review from maintainers
- Assign relevant reviewers based on changed components

## Code Review Process

### What Reviewers Look For

1. **Correctness**: Does the code work as intended?
2. **Testing**: Are tests adequate and passing?
3. **Code Style**: Does it follow the style guide?
4. **Documentation**: Is the code well-documented?
5. **Performance**: Are there any performance concerns?
6. **Security**: Are there any security implications?
7. **Breaking Changes**: Does this break existing functionality?

### Review Timeline

- Initial review typically within 48 hours
- Complex changes may take longer
- Follow up politely if no response after 1 week

### Review Outcomes

**Approved**: Changes look good, ready to merge (after any CI checks pass)

**Changes Requested**: Address reviewer feedback and push updates

**Commented**: Questions or suggestions, but not blocking merge

## Addressing Feedback

### 1. Make Requested Changes

Implement the feedback from reviewers:

```bash
# Make changes
vim src/some_file.cr

# Test the changes
crystal spec

# Commit the changes
git commit -m "fix(server): address review feedback on timeout handling"
```

### 2. Push Updates

Push new commits to your branch:

```bash
git push origin feature/your-feature-name
```

### 3. Respond to Comments

On GitHub, reply to review comments:
- Explain how you addressed the issue
- Ask clarifying questions if needed
- Mark resolved comments as done

### Squashing Commits (Optional)

Maintainers may ask you to squash multiple commits:

```bash
# Interactive rebase
git rebase -i HEAD~5  # For last 5 commits

# Mark commits to squash (change "pick" to "s")
# Save and close
# Edit the combined commit message

# Force push (careful!)
git push origin feature/your-feature-name --force-with-lease
```

## After Merge

### Update Your Fork

After your PR is merged, update your fork's main branch:

```bash
git checkout main
git fetch upstream
git rebase upstream/main
git push origin main
```

### Delete Your Branch

Optional: Delete the feature branch locally and remotely:

```bash
# Delete local branch
git branch -d feature/your-feature-name

# Delete remote branch
git push origin --delete feature/your-feature-name
```

## Continuous Integration

All pull requests run CI checks:

- **Crystal Tests**: `crystal spec`
- **Code Formatting**: `crystal tool format --check`
- **Build Verification**: Ensure the project builds
- **Linting**: Code quality checks

If CI fails:
1. Check the failure logs
2. Fix the issue locally
3. Push a new commit
4. CI will re-run automatically

## Code of Conduct

### Our Pledge

In the interest of fostering an open and welcoming environment, we pledge to make participation in our project and our community a harassment-free experience for everyone.

### Our Standards

Examples of behavior that contributes to a positive environment:
- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

Examples of unacceptable behavior:
- Use of sexualized language or imagery
- Personal attacks or insulting comments
- Trolling or insulting/derogatory comments
- Public or private harassment
- Publishing others' private information without permission
- Other unethical or unprofessional conduct

### Responsibilities

Project maintainers are responsible for clarifying the standards of acceptable behavior and are expected to take appropriate and fair corrective action in response to any instances of unacceptable behavior.

### Scope

This code of conduct applies both within project spaces and in public spaces when an individual is representing the project or its community.

### Reporting Issues

If you encounter or witness unacceptable behavior, please contact the project team at:
- **Email**: chris@watzon.tech
- **GitHub**: Report via [GitHub Issues](https://github.com/watzon/sellia/issues)

All reports will be reviewed and investigated.

## Getting Help

If you need help at any point:

1. **Check existing issues** - Your question may already be answered
2. **Read the documentation** - Start with [README](../../../README.md)
3. **Join discussions** - Comment on relevant issues
4. **Ask a question** - Open a new issue with the "question" label

## Recognition

Contributors are recognized in:
- Release notes for significant contributions
- The project's README for major contributors

Thank you for contributing to Sellia!

## Next Steps

- [Code Style Guidelines](code-style.md) - Write clean code
- [Commit Messages](commit-messages.md) - Write great commit messages
- [Testing](../development/testing.md) - Test your changes
