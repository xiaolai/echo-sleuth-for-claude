# Insight Taxonomy — Detailed Category Reference

## Category 1: Decisions

### Sub-types
- **Technology choice**: Chose library A over B
- **Architecture choice**: Chose pattern A over B
- **Trade-off**: Sacrificed X for Y
- **Scope decision**: Included/excluded feature
- **Process decision**: Workflow or methodology choice

### Extraction cues
- "I'll use...", "Let's go with...", "The better approach is..."
- AskUserQuestion tool with options → user selects one
- Plan mode entries listing alternatives

---

## Category 2: Mistakes & Corrections

### Sub-types
- **Syntax/Type error**: Code doesn't compile/run
- **Logic error**: Code runs but produces wrong results
- **Integration error**: Components don't work together
- **Environment error**: Wrong version, missing dependency, config issue
- **Approach error**: Entire approach was wrong, needed different strategy

### Severity levels
- **Critical**: Blocked progress, required significant rework
- **Moderate**: Required a few fix attempts
- **Minor**: Quick correction, low impact

---

## Category 3: Effective Patterns

### Sub-types
- **Debugging pattern**: Effective way to diagnose issues
- **Implementation pattern**: Effective code structure or approach
- **Testing pattern**: Effective way to verify correctness
- **Research pattern**: Effective way to find information
- **Communication pattern**: Effective way to describe requirements

---

## Category 4: Anti-patterns

### Sub-types
- **Premature optimization**: Optimized before it worked
- **Wrong abstraction**: Over-generalized or under-generalized
- **Missing context**: Started work without understanding enough
- **Tool misuse**: Used the wrong tool for the job
- **Scope creep**: Session expanded beyond original intent

---

## Category 5: User Preferences

### Sub-types
- **Tool preferences**: Which tools, frameworks, languages preferred
- **Style preferences**: Code style, naming, organization
- **Workflow preferences**: How they like to work (plan first vs dive in)
- **Communication preferences**: Level of detail, explanation style
- **Quality preferences**: Testing standards, review requirements

---

## Category 6: Architecture Knowledge

### Sub-types
- **Component map**: What exists and how it connects
- **Data flow**: How data moves through the system
- **Tech stack**: What technologies are used and why
- **Constraints**: Performance requirements, compatibility needs
- **Conventions**: Naming patterns, file organization, coding standards

---

## Category 7: Recurring Problems

### Sub-types
- **Flaky tests**: Tests that intermittently fail
- **Build issues**: Recurring build/compilation problems
- **Integration gaps**: Recurring mismatches between components
- **Environment drift**: Config that keeps needing adjustment
- **Regression**: Bugs that keep coming back after being fixed

---

## Category 8: Performance & Cost Patterns

### Metrics to track
- **Tokens per session**: Total input + output tokens
- **Cache efficiency**: cache_read_tokens / (cache_read_tokens + input_tokens)
- **Session length**: Time from first to last message
- **Turns per session**: Number of user-assistant exchanges
- **Compaction rate**: Sessions that needed context compaction
- **Error rate**: Percentage of tool calls that resulted in errors
- **Model distribution**: % sessions using opus vs sonnet vs haiku
