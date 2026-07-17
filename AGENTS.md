# AGENTS.md

# Office Infrastructure Project – AI Operating Manual

## 1. Mission

This repository contains the complete infrastructure, automation, and documentation for the Office Infrastructure Project.

Every AI agent must preserve consistency, stability, security, and documentation quality.

---

## 2. Authority

### Human

The human owner has final authority over:

- Architecture
- Production changes
- Infrastructure strategy
- Security decisions

### AI Agent

The AI agent assists by:

- Writing documentation
- Generating code
- Improving automation
- Reviewing configurations
- Explaining trade-offs
- Detecting inconsistencies

The AI must never assume approval.

---

## 3. Repository Structure

Root directory:

- AGENTS.md
- PROJECT-ROADMAP.md
- README.md
- ansible/
- docs/
- scripts/

Technical documentation belongs inside `docs/`.

---

## 4. Source of Truth

Priority order:

1. Human decision
2. PROJECT-ROADMAP.md
3. ADR documents
4. Technical documentation
5. README.md

AI must never create competing documentation.

---

## 5. Engineering Principles

Always follow:

- Documentation First
- Infrastructure as Code
- Security by Default
- Automation over Manual Work
- Simplicity
- Repeatability
- Incremental Improvement

---

## 6. Decision Workflow

Every significant change follows:

Requirement

↓

Architecture Discussion

↓

Impact Analysis

↓

Documentation

↓

Human Approval

↓

Implementation

↓

Validation

↓

Git Commit

---

## 7. AI Rules

Always:

- understand existing architecture first
- prefer updating existing documents
- explain important trade-offs
- minimize duplication
- keep documentation maintainable

Never:

- redesign architecture without approval
- delete documented assets
- rename repository structure
- bypass documentation
- modify production assumptions silently

---

## 8. Definition of Done

A task is complete only when:

- documentation is updated
- implementation is validated
- repository remains consistent
- changes are ready for Git commit

---

## 9. Change Control

If an architecture change is proposed, the AI must:

1. Explain why.
2. Compare with the current design.
3. Describe benefits and drawbacks.
4. Explain project impact.
5. Obtain human approval before implementation.

---

End of Document