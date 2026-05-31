# OpenShell Demo

Demo showing a GitHub Copilot-style agent working under NVIDIA OpenShell policy.

The demo is designed to be stage-safe first:

- `scripted` mode is deterministic and does not require network, OpenShell, Copilot, or GitHub.
- `live` mode follows the current OpenShell workflow and can be used once the host is fully rehearsed.
- The on-screen point is intentionally simple: same agent, same prompt, different policy.

## Demo

1. The agent lists and summarizes issues from GitHub.
2. OpenShell policy allows the read calls.
3. The agent tries to close an issue and push to `main`.
4. OpenShell denies the write call at L7.
5. The operator applies a narrower write policy with `openshell policy set ... --wait`.
6. The same agent prompt succeeds without restarting the sandbox.

## Quick Start

```bash
./scripts/preflight.sh
./scripts/reset.sh
./scripts/stage.sh
```

The tmux layout has three panes:

- Left/top: agent prompt and responses.
- Right: OpenShell-style decision stream.
- Left/bottom: policy command pane.

In the agent pane, run:

```text
list
push
```

In the policy pane, run:

```bash
./scripts/policy-apply.sh writeable
```

Then return to the agent pane and run:

```text
push
```

## Speaker Runbook

### T-10 Minutes

```bash
./scripts/reset.sh
./scripts/preflight.sh
./scripts/stage.sh
```

Expected preflight result:

```text
PASS scripted demo assets are ready
```

Expected decisions pane after startup:

```text
waiting for decisions in .demo-runtime/audit.log
```

### Act 1: Establish

Say:

> We are running an agent workflow with OpenShell between the agent and the outside world. The left pane is the agent. The right pane is OpenShell decisions. The bottom pane is policy.

No command needed.

### Act 2: Useful Work

In the agent pane:

```text
list
```

Expected agent output:

```text
I found 3 open issues.
```

Expected decisions output:

```text
ALLOW GET api.github.com/repos/alig80/OpenShell-demo/issues
```

Say:

> Reads are useful and allowed.

### Act 3: The Denial

In the agent pane:

```text
push
```

Expected agent output:

```text
I can't close issue #3 or push to main.
```

Expected decisions output:

```text
DENY PATCH api.github.com/repos/alig80/OpenShell-demo/issues/3
```

Say:

> This is not a token failure. The request never reaches GitHub. OpenShell denied it at the policy boundary.

### Act 4: Policy Update

In the policy pane:

```bash
./scripts/policy-apply.sh writeable
```

Expected decisions output:

```text
RELOAD policy: copilot-readonly -> copilot-writeable, 0 restarts
```

In the agent pane:

```text
push
```

Expected agent output:

```text
Done. Issue #3 is closed and the fix branch was pushed.
```

Expected decisions output:

```text
ALLOW PATCH api.github.com/repos/alig80/OpenShell-demo/issues/3
ALLOW POST  api.github.com/repos/alig80/OpenShell-demo/git/refs
```

Close with:

> Same agent. Same prompt. The policy changed, not the code.

## Live Mode Notes

Scripted mode is what you should use on stage unless the live path has passed dress rehearsal twice in the exact room.

OpenShell v0.0.52 was the latest stable release when this repo was created. Install with:

```bash
curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | OPENSHELL_VERSION=v0.0.52 sh
```

The live OpenShell policy workflow is:

```bash
openshell provider create --name build-demo-github --type github --from-existing
openshell sandbox create --name copilot-demo --keep --provider build-demo-github -- codex
openshell policy set copilot-demo --policy policies/copilot-readonly.yaml --wait
openshell term
openshell policy set copilot-demo --policy policies/copilot-writeable.yaml --wait
```

Use `copilot`, `gh copilot`, `codex`, or another agent binary depending on what is installed on the demo host. The policy files are written against OpenShell's current `version: 1` policy schema.

## Files

- `policies/copilot-readonly.yaml`: allows GitHub reads and blocks writes.
- `policies/copilot-writeable.yaml`: allows the narrow issue-update and ref-create operations used in Act 4.
- `scripts/stage.sh`: opens the three-pane tmux demo layout.
- `scripts/agent-run.sh`: deterministic agent actor, plus a placeholder live mode.
- `scripts/decision-viewer.sh`: renders the decision stream with ALLOW, DENY, and RELOAD colors.
- `scripts/policy-apply.sh`: applies policy state for scripted mode and can run `openshell policy set` in live mode.
- `scripts/preflight.sh`: validates the demo assets and optional live dependencies.
- `scripts/seed-repo.sh`: optional GitHub issue seeding for a real repo.
- `fallback/demo.cast`: tiny asciinema fallback for narrating the core flow if the terminal setup fails.

## Reset

For the stage-safe scripted demo:

```bash
./scripts/reset.sh
```

For a real GitHub target, seed issues after authenticating `gh`:

```bash
./scripts/seed-repo.sh --repo alig80/OpenShell-demo
```

## Sources

- OpenShell releases: https://github.com/NVIDIA/OpenShell/releases
- OpenShell GitHub sandbox tutorial: https://docs.nvidia.com/openshell/get-started/tutorials/github-sandbox
- OpenShell policy schema: https://docs.nvidia.com/openshell/reference/policy-schema
- OpenShell sandbox policy guide: https://docs.nvidia.com/openshell/sandboxes/policies
