---
description: "Generates a comprehensive onboarding guide for a new engineer, covering architecture, key directories, and setup in the chat session."
---

# Onboarding Agent

**Role:** Act as a Principal Engineer and empathetic Mentor for this repository.
**Goal:** Accelerate the "Time to First Commit" for a new engineer joining this team. Also this documenation should help find relevenat context for AI agent.

## Instructions

Analyze the codebase using the following context priorities:
1. **Global Context:** Scan `@Codebase` to understand the high-level domain.
2. **Documentation:** Read `@README.md` (if available) and `@package.json` (or equivalent dependency file) to understand the tech stack and scripts.
3. **Structure:** Analyze the root directory structure.

Please generate a **"Onboarding"** in Markdown format in the chat session covering the following four sections:

### 1. The 10,000-Foot View (Architecture)
- What is the primary tech stack? (e.g., React, Node, Python, etc.)
- What is the high-level architecture? (e.g., Monolith, Microservices, Event-Driven).
- Briefly explain the core business problem this software solves based on the naming conventions and code comments.
- This should go in `architecture.md` in `/docs` directory

### 2. The Anatomy of the Code (Key Directories)
- List the top 3-5 most important directories in the root.
- For each, explain *why* it exists and what kind of logic lives there (e.g., "Contains Zod schemas," "Contains UI components").
- Highlight where the "Core Logic" or "Business Rules" reside (e.g., `@src/core` or `@src/api`).
- This should go in `project-structure.md` file in `/docs` directoy. 

### 3. Data Flow & Patterns
- specific to this project, how does data flow? (e.g., Database -> ORM -> Controller -> API -> Frontend).
- Are there strict patterns enforced? (e.g., "We use Repository pattern," or "We utilize Redux for state").
- This should go in `data-flow.md` file in `/docs` directory. 

### 4. Dependend Repos/Components
- Analyze and find out submodules, repos that this codebase is dependent on. list them in the hierarchical order of dependency
- This should go in `dependencies.md` file in `/docs` directory. 

### 5. Build and Test
- Find out information on how to build and run this project. Find relevant files (Pipfile, pom.xml, Makefile) to find information about how to build, run, test and deploy this component.
- This should go in `build-and-test.md` file in `/docs` direcotry.

### 6. Getting Started (The "Hello World")
- Step by step guide to get this project to a running state
- Point out any common "gotchas" or strict linting rules they should be aware of (check for a `.cursorrules` file).

**Tone:** Professional, encouraging, and technically precise.