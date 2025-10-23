# SupraLottery – Testnet Runbook

Полный сценарий подготовки, сборки, публикации и проверки модульных контрактов SupraLottery на Supra testnet.

---

## 0. Предварительные требования
- Docker Desktop или Podman (поддержка `docker compose`).
- Python 3.10+.
- Тестовые токены SUPRA на аккаунте.
- Профиль Supra CLI:
  1. Скопируйте `supra/configs/testnet.yaml` → `supra/configs/testnet.local.yaml`.
  2. Заполните `account_address`, `private_key`, параметры газа.
  3. Файл уже исключён `.gitignore`.

Проверка баланса:
```powershell
docker compose run --rm -e SUPRA_PROFILE=my_profile --entrypoint bash supra_cli `
  -lc "/supra/supra move account balance --profile my_profile"
```

---

## 1. Зависимости Move (aptos-core)
### Linux / WSL
```bash
bash supra/scripts/bootstrap_move_deps.sh
```
Команда скачает aptos-core commit `7d1e62c9a5394a279a73515a150e880200640f06` и заполнит кеш `~/.move`.

### Windows без WSL
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

---

## 2. Компиляция пакетов
Все команды выполняются внутри контейнера `supra_cli`.
```powershell
# lottery_core
docker compose run --rm --entrypoint bash supra_cli `
  -lc "/supra/supra move tool compile --package-dir /supra/move_workspace/lottery_core         --skip-fetch-latest-git-deps"
# lottery_support
docker compose run --rm --entrypoint bash supra_cli `
  -lc "/supra/supra move tool compile --package-dir /supra/move_workspace/lottery_support         --skip-fetch-latest-git-deps"
# lottery_rewards
docker compose run --rm --entrypoint bash supra_cli `
  -lc "/supra/supra move tool compile --package-dir /supra/move_workspace/lottery_rewards         --skip-fetch-latest-git-deps"
```
(Для Podman адаптируйте команду.)

---

## 3. Unit-тесты
```bash
python -m supra.scripts.cli move-test --workspace supra/move_workspace --package lottery_core --skip-fetch-latest-git-deps
python -m supra.scripts.cli move-test --workspace supra/move_workspace --package lottery_support --skip-fetch-latest-git-deps
python -m supra.scripts.cli move-test --workspace supra/move_workspace --package lottery_rewards --skip-fetch-latest-git-deps
```
или
```powershell
docker compose run --rm --entrypoint bash supra_cli `
  -lc "/supra/supra move tool test --package-dir /supra/move_workspace/lottery_core --skip-fetch-latest-git-deps"
```

---

## 4. Публикация пакетов (Supra testnet)
Последовательность: core → support → rewards.
```powershell
docker compose run --rm -e SUPRA_PROFILE=my_profile --entrypoint bash supra_cli `
  -lc "/supra/supra move tool publish --package-dir /supra/move_workspace/lottery_core         --included-artifacts none --skip-fetch-latest-git-deps         --gas-unit-price 100 --max-gas 150000 --expiration-secs 600 --assume-yes"
```
После выполнения сохраните хеш транзакции и повторите команду для `lottery_support`, `lottery_rewards`.

---

## 5. Инициализация после публикации
```powershell
bash supra/scripts/sync_lottery_queues.sh
```
Если bash недоступен, выполните команды из скрипта через контейнер `supra_cli`. Скрипт синхронизирует очереди истории/покупок и проверяет capability.

Дополнительно выполните whitelisting VRF и депозиты согласно `SupraLottery/docs/testnet_deployment_checklist.md`.

---

## 6. Проверки
- `supra move tool show --query module ...` — модули опубликованы.
- `lottery_core::treasury_v1::is_initialized`, `lottery_core::rounds::history_queue_length` — состояние ресурсов.
- Тестовый сценарий: покупка билета, ручной розыгрыш.
- Сохраните хеши транзакций и параметры газа в runbook/чеклисте.

---

## 7. Legacy fallback
Для возврата к монолитной версии:
```powershell
docker compose run --rm -e SUPRA_PROFILE=my_profile --entrypoint bash supra_cli `
  -lc "/supra/supra move tool publish --package-dir /supra/move_workspace/lottery_backup         --included-artifacts none --skip-fetch-latest-git-deps         --gas-unit-price 100 --max-gas 200000 --expiration-secs 600 --assume-yes"
```
Дальнейшие шаги — по разделу Legacy в чеклисте.

---

## 8. Полезные ссылки
- <https://docs.supra.com>
- `supra/scripts/publish_lottery_packages.sh`
- `supra/scripts/sync_lottery_queues.sh`
- `SupraLottery/docs/testnet_deployment_checklist.md`

---

## 9. Завершение релиза
- Чеклист выполнен, хеши/параметры задокументированы.
- Создан git-тег (`release/testnet-YYYYMMDD`) или релизная ветка.
- Обновлены фронтенд/интеграционные конфиги при необходимости.
