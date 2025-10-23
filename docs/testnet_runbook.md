# SupraLottery Testnet Runbook

This runbook describes how to prepare the environment, build, publish and verify the modular SupraLottery contracts on Supra testnet.

## 1. Requirements
- Docker Desktop (or Podman) with `docker compose`.
- Python 3.10+ for helper scripts.
- Local Supra CLI profile: copy `supra/configs/testnet.yaml` to `supra/configs/testnet.local.yaml`, fill `account_address` and `private_key`.
- Test SUPRA balance on the selected account.

## 2. Bootstrap Move dependencies
```bash
bash supra/scripts/bootstrap_move_deps.sh
```
This pulls commit `7d1e62c9a5394a279a73515a150e880200640f06` of aptos-core and hydrates the local Move cache.
If you are on Windows without WSL/bash, run the Python fallback:
```powershell
python -c "import os, tarfile, tempfile, shutil, urllib.request; from pathlib import Path; commit='7d1e62c9a5394a279a73515a150e880200640f06'; repo_url='https://github.com/Entropy-Foundation/aptos-core'; framework_subpath=Path('aptos-move/framework'); needed_dirs=['move-stdlib','supra-framework','aptos-stdlib','supra-stdlib']; move_home=Path(os.environ.get('MOVE_HOME', Path.home()/'.move')); cache_prefix=f'https___github_com_Entropy-Foundation_aptos-core_git_{commit}'; target_base=move_home/cache_prefix/framework_subpath;
if all((target_base/d).exists() for d in needed_dirs):
    print('Dependencies already cached at', target_base); raise SystemExit(0)
move_home.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory() as tmpdir:
    tmpdir=Path(tmpdir); archive=tmpdir/'aptos-core.tar.gz'; url=f'{repo_url}/archive/{commit}.tar.gz'; print('Downloading', url);
    with urllib.request.urlopen(url) as resp, open(archive,'wb') as f: shutil.copyfileobj(resp, f)
    print('Extracting archive...');
    with tarfile.open(archive, 'r:gz') as tf: tf.extractall(tmpdir); source_base=tmpdir/f'aptos-core-{commit}'/framework_subpath
    if not source_base.exists(): raise SystemExit(f'Missing {source_base}')
    for d in needed_dirs:
        src=source_base/d; dst=target_base/d; dst.parent.mkdir(parents=True, exist_ok=True);
        if dst.exists(): shutil.rmtree(dst); shutil.copytree(src, dst); print('Installed', dst)
print('Move dependencies installed at', target_base)"
```
This downloads `aptos-core` (branch `dev`) and seeds the `~/.move` cache so further builds do not fetch git deps every time.

## 3. Build packages
```powershell
docker compose run --rm --entrypoint bash supra_cli `
  -lc "/supra/supra move tool compile --package-dir /supra/move_workspace/lottery_core \
        --skip-fetch-latest-git-deps"
docker compose run --rm --entrypoint bash supra_cli `
  -lc "/supra/supra move tool compile --package-dir /supra/move_workspace/lottery_support \
        --skip-fetch-latest-git-deps"
docker compose run --rm --entrypoint bash supra_cli `
  -lc "/supra/supra move tool compile --package-dir /supra/move_workspace/lottery_rewards \
        --skip-fetch-latest-git-deps"
```
These commands execute inside the `supra_cli` container, so no local bash/WSL is required. Podman users can adapt the command.

## 4. Run unit tests
```bash
python -m supra.scripts.cli move-test --workspace supra/move_workspace --package lottery_core --skip-fetch-latest-git-deps
python -m supra.scripts.cli move-test --workspace supra/move_workspace --package lottery_support --skip-fetch-latest-git-deps
python -m supra.scripts.cli move-test --workspace supra/move_workspace --package lottery_rewards --skip-fetch-latest-git-deps
```

## 5. Publish packages
Example for Docker (replace `my_profile`):
```powershell
docker compose run --rm -e SUPRA_PROFILE=my_profile --entrypoint bash supra_cli `
  -lc "/supra/supra move tool publish --package-dir /supra/move_workspace/lottery_core         --included-artifacts none --skip-fetch-latest-git-deps         --gas-unit-price 100 --max-gas 150000 --expiration-secs 600 --assume-yes"
```
Run the same command for `lottery_support` and `lottery_rewards`. For Podman see `supra/scripts/publish_lottery_packages.sh` (handles volume suffixes and extra args).

## 6. Post-publish initialisation
```bash
bash supra/scripts/sync_lottery_queues.sh
```
Use capability APIs to drain/initialise history and purchase queues. Ensure VRF whitelisting and deposits are configured (see docs).

## 7. Validation checklist
- Inspect events via `supra move tool show` or `supra move tool view`.
- Confirm treasury and queue state via view functions (`lottery_core::treasury_v1::is_initialized`, etc.).
- Execute a manual draw or integration script.

## 8. Legacy fallback
If monolithic deployment is required:
```powershell
docker compose run --rm -e SUPRA_PROFILE=my_profile --entrypoint bash supra_cli `
  -lc "/supra/supra move tool publish --package-dir /supra/move_workspace/lottery_backup         --included-artifacts none --skip-fetch-latest-git-deps         --gas-unit-price 100 --max-gas 200000 --expiration-secs 600 --assume-yes"
```
Follow historical instructions for initialisation (see `SupraLottery/docs/testnet_deployment_checklist.md`).

## 9. References
- https://docs.supra.com
- `supra/scripts/publish_lottery_packages.sh`
- `supra/scripts/sync_lottery_queues.sh`
