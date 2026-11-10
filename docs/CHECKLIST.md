# Delivery checklist — SCZ-Architecture

Review every item before creating `release/v1.0` and merging `develop` into `main`.

## Product
- [ ] `python3 build/build.py` regenerates `dist/Simulator_SIS131.ods` without errors.
- [ ] `python3 tests/run_tests.py` ends with **12/12 passed** (P1, P2, P3 and EDITOR with LRU and FIFO).
- [ ] The workbook opens on **Windows** with macros enabled (Macro Security = Medium) and every button responds.
- [ ] P1 shows `7 x 5 = 35`; P2 echoes the typed text on the LCD; P3 ends with CX = AA, 11 page faults and 3 swap-outs.
- [ ] The animation is visible at speed 3 (token on the buses, HIT/MISS, page fault, swap-out and swap-in).

## Identity
- [ ] Team name in the SIMULATOR header (`src/data/team.txt`).
- [ ] Team logo in the spreadsheet, in both READMEs and in the defense slides (`assets/logo.png`).
- [ ] Members listed: Josue Cartagena, Jussel Avila.

## Documentation
- [ ] `README.md` (Spanish) and `README_EN.md` (English) have the same sections.
- [ ] The 3 Mermaid diagrams render on GitHub.
- [ ] ISA table (20 instructions), control word (21 signals), memory map, user manual and macro setup are present.
- [ ] The link to `dist/Simulator_SIS131.ods` works.

## Methodology
- [ ] Every issue was developed on a personal `feature/<student>/<module>` branch and merged through a reviewed Pull Request.
- [ ] Semantic commits (`feat`, `fix`, `docs`, `test`, `chore`) from both members.
- [ ] Every Kanban card is in **Done** with its acceptance criteria checked.
- [ ] No commits after the official closing date and time.

## Defense (30 min)
- [ ] Each member presents a technical part: buses / tri-state, virtual memory / page fault, L1/L2 cache, I/O, Gitflow.
- [ ] Live demo of the 3 programs; live code change prepared (e.g. multiplication → addition in PROGRAMS).
- [ ] Team uniform.
