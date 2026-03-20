---
description: Refactor, tidyup, cleanup, minimalistcode, leancode
---
When asked to sanitize or tidyup the code base, Your goal is to maximize code readability, maintainability, and performance while **strictly preserving** existing functionality. You are hostile to redundancy, verbosity, and "zombie comments.". The output must be in a quality ready to commit to the repository.
**The Prime Directive:** NO FUNCTIONAL CHANGES. The AST (Abstract Syntax Tree) of the logic must remain equivalent. Only the structure, aesthetics, and organization may change.

### Sanitation Rules (The "Clean Code" Standard):

#### Eradicate Redundant Comments ("Zombie Comments"):
- DELETE all comments that describe what the code is doing. The code itself should be self-documenting.
- DELETE all conversational artifacts in comments.
- DELETE all commented-out code blocks. If it is dead, remove it. Git history is our backup.
- KEEP comments that explain why a non-obvious decision was made.
- KEEP JSDoc/DocStrings for public API interfaces, but enforce brevity.

#### Detect & Fix the below code smells:
- Bloaters
- Object Orientation abusers
- Change Preventers
- Dispensables
- Couplers

#### Lean Code and Project:
* Reduce the Cyclomatic Complexity of the codebase
* Construct a dependency tree of the codebase, start walking the dependency tree to identify disconnected components and disconnected code files
* Identify dangling code files which are disconnected from the project or doesn't contribute to the overall functionality and mark them for removal. Ask the users permission to delete it with your reasoning for deletion.
* Remove intermediate test scripts that are developed to test functionality of a specific function which are not part of unit or integration test suite.
* Remove all redundant markdown that doesn't contribute to the user experience or developer experience.
* Use a minimalist approach (without affecting functionality and readability) and keep optimal number of lines of code 

#### Enforce DRY (Don't Repeat Yourself):
- Identify repeated logic blocks (3+ lines). Extract them into private helper functions with descriptive verbs as names.
- If a utility exists in the broader codebase (e.g., date-fns, lodash, or internal utils/), import it instead of re-implementing the logic inline. Check imports carefully.

#### Simplify Control Flow:
- **Guard Clauses:** Convert nested if/else blocks into guard clauses (early returns) to reduce indentation depth.
- **Functional Patterns:** Replace imperative for loops with functional methods (.map, .filter, .reduce) where it improves readability, unless in a critical hot path requiring raw performance.
- **Boolean Simplification:** Simplify boolean expressions (e.g., if (isValid == true) -> if (isValid)).

#### Formatting and Structure:
- **Constant Extraction:** Move all "magic numbers" and hardcoded strings to named constants at the top of the file or a config file.
- **Import Hygiene:** Sort imports. Remove unused imports immediately. Group external and internal imports.

#### Anti-Hallucination Safety Checks:
- **VERIFY IMPORTS:** Do not import any library that is not explicitly present in the file's current context or the project's package.json/requirements.txt.
- If you suspect a library is needed but missing, ask for permission before assuming it exists.

#### Code Structure
- **Guard Clauses:** Always use early returns to avoid deep nesting.
    BAD: if (x) { if (y) { return z; } }
    GOOD: if (!x) return; if (!y) return; return z;

- **Function Length:** Target functions under 40 lines. If longer, suggest splitting into sub-routines.

- **Variable Naming:** Variables must be descriptive nouns (e.g., userList, isAuthorized). 

- Execute the 'Safe' changes first. Remove all zombie comments and unused imports. Apply guard clauses.

**Output:** Return only the cleaned code block. Do not explain what you did. Do not say "Here is the cleaned code." Just the code.