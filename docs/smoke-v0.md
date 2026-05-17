# V0 Smoke Workflow

Run the repeatable local smoke workflow with:

```sh
bash scripts/smoke-v0.sh
```

The workflow builds `tweb`, starts the executable through stdin/stdout with `--no-model-required`, waits for a Ready Block, sends a plain-text Task Turn that navigates to a controlled URL, verifies a Result Block, verifies Trace Command output, writes an HTML Artifact File, and quits cleanly.

It does not require real third-party credentials.
