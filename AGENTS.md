# Testing

Always verify changes with the Lint script.

If a role that was changed contains a molecule test run the molecule test.

## Lint script

A script running shellcheck and ansible-lint.

```bash
./check
```

## Ansible Molecule tests

Molecule is configured to use podman via `.config/molecule/config`.
Usally there is no need to configure anything in the local molecule.yml

Example:
```
venv molecule
cd roles/<rolename>
ansible test --all
```

Always use the --all flag to run all scenarios except when you want to only run a specific scenario
