# Claude Code Instructions

## Project Overview

This is a Java/Spring Boot multi-module Maven project for a platform system.

## Spec-Driven Development

This project uses GitHub Spec Kit for specification-driven development.

### Slash Commands

- `/specify` - Create a new feature specification
- `/plan` - Generate a technical implementation plan
- `/tasks` - Break down the plan into actionable tasks

### Workflow

1. When starting a new feature, first run `/specify` to create a specification
2. After the spec is approved, run `/plan` to create a technical plan
3. Break down the plan with `/tasks` to get actionable implementation steps
4. Implement the tasks step by step

## Project Structure

```
platfrom-parent/
├── platform-common/     # Common utilities and base classes
├── platform-config/     # Configuration server
├── platform-gateway/    # API Gateway
├── pom.xml             # Parent POM
└── .specify/           # Spec-driven development artifacts
```

## Code Standards

- Follow Java coding conventions
- Use Spring Boot best practices
- Write unit tests for new features
- Document APIs with OpenAPI/Swagger

## Important Notes

- Always check `.specify/specs/` for existing specifications before implementing
- Update plans in `.specify/plans/` when technical approach changes
- Track task completion in `.specify/tasks/`
