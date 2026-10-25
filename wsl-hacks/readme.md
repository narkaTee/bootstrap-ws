# WSL Hacks

Wrappers for running Windows tools from WSL.

```bash
mkdir -p ~/.local/bin
cp op ssh ssh-add ~/.local/bin/
```

## op

Requires Ruby (standard library only) and Windows `op.exe` on PATH.
Non-`run` commands are forwarded unchanged to `op.exe`.

For `op run`, the wrapper parses the env template, resolves whole-value `op://`
references with `op.exe read --no-newline`, and executes the Linux command.
Secrets remain in memory; no temporary secret files or shell evaluation are used.

```bash
op run --no-masking --env-file template.env --account my-account -- bash
```

Supports one `--env-file FILE`, optional `--account ACCOUNT`, and a required `--`
command separator. `--no-masking` is mandatory because output masking is not
implemented. Unsupported options are rejected.

### Template format

```dotenv
# Comments and blank lines are allowed.
TOKEN=op://vault/item/token
OTHER_TOKEN="op://vault/item/other-token"
MODE=development
DESCRIPTION="a value with spaces"
EMPTY=
```

- Shell-style variable names; assignments split at the first `=`.
- Surrounding whitespace and matching outer quotes are removed.
- CRLF files are supported; duplicate assignments use the last value.
- No `export` prefix, multiline template values, interpolation, escape processing,
  inline-comment processing, or embedded `op inject` expressions.
- Only template entries are resolved, not inherited environment variables.
- Secrets are resolved after parsing and preserved verbatim, including newlines.
  NUL bytes are rejected.
- Each reference requires one CLI call. Lookup failures abort before execution.

### Tests

Requires Minitest. Tests use a temporary fake `op.exe` and dummy values.

```bash
ruby wsl-hacks/test_op.rb
```
