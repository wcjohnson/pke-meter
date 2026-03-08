# AGENTS.md

## Repository Purpose
`pke-meter` is a Factorio mod that detects ghost entities which still need construction in a given roboport network, then outputs the total outstanding ghost count for that network as circuit signals from a combinator.

## Technical Context
- Language: Lua
- Runtime/API: Factorio Modding API
- Architecture direction: event-driven state updates

## Implementation Direction
The mod should track outstanding ghosts by reacting to relevant world changes, including:
- Ghost entities being created, revived, or removed
- Roboports being built, mined, destroyed, or otherwise causing logistic networks to expand, merge, or split

Use these events to incrementally maintain accurate network ghost counts.

## Design Constraints
- Do not use `on_tick` polling for counting logic.
- Do not use wide-area periodic scanning as a primary mechanism.
- Prefer event-based bookkeeping and targeted reconciliation when necessary.

## Core Library Usage
When implementing features, prefer existing helpers and abstractions in `lib/core` where possible, instead of introducing duplicate utility code.

## Agent Guidance
When proposing or implementing changes in this repository:
- Keep solutions aligned with Factorio event lifecycle and deterministic state updates.
- Preserve the no-polling / no-wide-scan design intent.
- Reuse `lib/core` modules first; add new primitives only when existing ones are insufficient.
- Keep behavior focused on per-network ghost accounting and circuit output correctness.
