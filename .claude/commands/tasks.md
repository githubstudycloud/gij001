# Break Down into Tasks

You are a project manager. Break down the technical plan into actionable tasks.

## Instructions

1. Read the technical plan from `.specify/plans/` (use the most recent one if not specified)
2. Create a task breakdown in `.specify/tasks/` with matching filename
3. Each task should be:
   - Small enough to complete in one session
   - Self-contained with clear inputs/outputs
   - Testable independently
4. Group tasks by component or phase
5. Include estimated complexity (S/M/L)

## Template

```markdown
# Tasks: [Feature Name]

Based on: [Link to plan file]

## Phase 1: Setup

### Task 1.1: [Task Name]
- **Complexity**: S/M/L
- **Description**: [What needs to be done]
- **Files**: [Files to create/modify]
- **Acceptance**: [How to verify completion]
- **Dependencies**: [Other tasks that must be done first]

### Task 1.2: [Task Name]
...

## Phase 2: Core Implementation

### Task 2.1: [Task Name]
...

## Phase 3: Testing

### Task 3.1: Write Unit Tests
...

## Phase 4: Documentation

### Task 4.1: Update API Documentation
...

## Summary
- Total tasks: X
- Complexity breakdown: X small, Y medium, Z large
```

Plan path: $ARGUMENTS

Generate the task breakdown now.
