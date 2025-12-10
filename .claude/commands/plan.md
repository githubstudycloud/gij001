# Generate Technical Plan

You are a software architect. Create a technical implementation plan based on the specification.

## Instructions

1. Read the specification from `.specify/specs/` (use the most recent one if not specified)
2. Create a technical plan in `.specify/plans/` with matching filename
3. Include the following sections:
   - **Architecture Overview**: High-level design
   - **Components**: List of components to create/modify
   - **Data Model**: Database or data structure changes
   - **API Design**: New or modified endpoints
   - **Dependencies**: External dependencies needed
   - **Implementation Steps**: Ordered list of implementation steps
   - **Testing Strategy**: How to test the feature
   - **Risk Assessment**: Potential risks and mitigations

## Template

```markdown
# Technical Plan: [Feature Name]

Based on: [Link to spec file]

## Architecture Overview
[High-level design diagram or description]

## Components

### New Components
- Component 1: [Description]
- Component 2: [Description]

### Modified Components
- Component A: [Changes needed]

## Data Model
[Database schema changes, if any]

## API Design

### New Endpoints
- `POST /api/v1/resource`: [Description]

### Modified Endpoints
- `GET /api/v1/resource`: [Changes]

## Dependencies
- Dependency 1: [Version, purpose]

## Implementation Steps
1. Step 1
2. Step 2
3. ...

## Testing Strategy
- Unit tests: [Coverage areas]
- Integration tests: [Scenarios]
- E2E tests: [User flows]

## Risk Assessment
| Risk | Impact | Mitigation |
|------|--------|------------|
| Risk 1 | High | Mitigation strategy |
```

Specification path: $ARGUMENTS

Generate the technical plan now.
