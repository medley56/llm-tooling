---
paths:
  - "**/tests/**/*.py"
  - "**/test_*.py"
  - "**/conftest.py"
---

# Python Test Suite Factoring

Default conventions for structuring a Python test suite. Where a repo has
established a different pattern, follow the repo. Say so once when it comes up;
do not re-raise it throughout a session.

## Suite Layout

- Use pytest.
- Separate tests by type under `tests/`: `tests/unit/`, `tests/integration/`,
  `tests/e2e/`.
- Build fixtures in a plugins module — one or several — rather than defining
  every fixture inline in test modules.
- Use one mocking library and one mocking pattern per repo. Do not mix.
- Group tests with `TestCase` classes only where the existing suite already does.

## Invariants for Every Test

- **Independent and order-independent.** No test may depend on another having run
  first, and setup and teardown are fully automated.
- **Leaves no trace in the repo.** Generated files, caches, and artifacts are
  cleaned up; a test run never leaves the working tree dirty.

## Unit Tests

Small-scale tests that run short call stacks and verify that functions and
classes fulfill the promises they make.

- Mirror the source layout: `package/module/file.py` is tested by
  `tests/unit/test_module/test_file.py`.
- Never alter external configuration, caches, or state.
- Never hit real web APIs.

## Integration Tests

Tests that verify segments of the repo work together to accomplish a
higher-level task.

- Organize by the functionality under test — usually the top-level call the test
  drives — not by source layout.
- May reach real external resources such as infrastructure.
- Assert on the overall behavior that depends on the non-mocked resources, not on
  internal steps.

## End-to-End Tests

Tests that exercise the full system through its real entry points, the way a
user or operator would.

- Organize by test goal. Structure will not track the source layout.
- Assert on the outcome of the run, not on the order or progress of its steps.
- Clean up any external resources the test creates, including on failure.
- Keep them few. They are the slowest and most brittle tests in the suite;
  push coverage down to the unit and integration layers wherever it fits.
