#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
WORKSPACE_ROOT="${REPO_ROOT}/SupraLottery/supra/move_workspace"
LINK_ROOT="${ROOT_DIR}/move_workspace"
PACKAGES=("lottery_core" "lottery_support" "lottery_rewards")

BASE_PACKAGE_FILE="${WORKSPACE_ROOT}/lottery/Move.toml"

if [ ! -f "${BASE_PACKAGE_FILE}" ]; then
  echo "[setup_lottery_packages] Не найден базовый пакет lottery (${BASE_PACKAGE_FILE})" >&2
  exit 1
fi

declare -A PACKAGE_MODULES=(
  [lottery_core]="main_v2 instances rounds operators treasury_v1 treasury_multi"
  [lottery_support]="history metadata migration"
  [lottery_rewards]="autopurchase jackpot nft_rewards referrals store vip"
)

declare -A MODULE_FILES=(
  [lottery_core:main_v2]="Lottery.move"
  [lottery_core:instances]="LotteryInstances.move"
  [lottery_core:rounds]="LotteryRounds.move"
  [lottery_core:operators]="Operators.move"
  [lottery_core:treasury_v1]="Treasury.move"
  [lottery_core:treasury_multi]="TreasuryMulti.move"
  [lottery_support:history]="History.move"
  [lottery_support:metadata]="Metadata.move"
  [lottery_support:migration]="Migration.move"
  [lottery_rewards:autopurchase]="Autopurchase.move"
  [lottery_rewards:jackpot]="Jackpot.move"
  [lottery_rewards:nft_rewards]="NftRewards.move"
  [lottery_rewards:referrals]="Referrals.move"
  [lottery_rewards:store]="Store.move"
  [lottery_rewards:vip]="Vip.move"
)

update_addresses_block() {
  local pkg="$1"
  local target="$2"
  python3 - "$BASE_PACKAGE_FILE" "$pkg" "$target" <<'PY'
import sys
from pathlib import Path

base_path = Path(sys.argv[1])
pkg = sys.argv[2]
target_path = Path(sys.argv[3])

try:
    import tomllib  # type: ignore[attr-defined]
except ModuleNotFoundError:  # pragma: no cover - fallback для более старых Python
    import tomli as tomllib  # type: ignore

if not base_path.exists():
    print(f"[setup_lottery_packages] Не найден базовый Move.toml: {base_path}", file=sys.stderr)
    sys.exit(1)

if not target_path.exists():
    print(f"[setup_lottery_packages] Не найден целевой Move.toml: {target_path}", file=sys.stderr)
    sys.exit(1)

data = tomllib.loads(base_path.read_text())
addresses = data.get("addresses")
if not isinstance(addresses, dict) or not addresses:
    print(f"[setup_lottery_packages] В {base_path} отсутствует секция [addresses]", file=sys.stderr)
    sys.exit(1)

items = list(addresses.items())
keys = [key for key, _ in items]
alias_map = {
    "lottery_core": ["lottery_core"],
    "lottery_support": ["lottery_core", "lottery_support"],
    "lottery_rewards": ["lottery_core", "lottery_rewards"],
}
alias_keys = alias_map.get(pkg, [])
if alias_keys:
    base_value = addresses.get("lottery")
    if base_value is None:
        print(f"[setup_lottery_packages] В {base_path} отсутствует адрес 'lottery'", file=sys.stderr)
        sys.exit(1)

    insert_idx = keys.index("lottery") + 1 if "lottery" in keys else len(items)
    for alias_key in alias_keys:
        if alias_key in keys:
            existing_idx = keys.index(alias_key)
            items.pop(existing_idx)
            keys.pop(existing_idx)
            if existing_idx < insert_idx:
                insert_idx -= 1

        items.insert(insert_idx, (alias_key, base_value))
        keys.insert(insert_idx, alias_key)
        insert_idx += 1


lines = ["[addresses]"]
for key, value in items:
    lines.append(f"{key} = \"{value}\"")
lines.append("")

text = target_path.read_text()
target_lines = text.splitlines()

start = next((i for i, line in enumerate(target_lines) if line.strip() == "[addresses]"), None)
if start is None:
    insert_idx = next((i for i, line in enumerate(target_lines) if line.strip().startswith("[dependencies]")), len(target_lines))
    new_lines = target_lines[:insert_idx] + lines + target_lines[insert_idx:]
else:
    end = start + 1
    while end < len(target_lines):
        stripped = target_lines[end].strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            break
        end += 1
    new_lines = target_lines[:start] + lines + target_lines[end:]

trailing_newline = "\n" if text.endswith("\n") else ""
target_path.write_text("\n".join(new_lines) + trailing_newline)
PY
}

ensure_directories() {
  local pkg="$1"
  mkdir -p "${WORKSPACE_ROOT}/${pkg}/sources"
  mkdir -p "${LINK_ROOT}"
}

ensure_symlink() {
  local pkg="$1"
  local link_path="${LINK_ROOT}/${pkg}"
  local target_rel="../SupraLottery/supra/move_workspace/${pkg}"

  if [ -L "${link_path}" ]; then
    return
  fi

  if [ -e "${link_path}" ]; then
    echo "[setup_lottery_packages] Предупреждение: ${link_path} существует и не является симлинком." >&2
    return
  fi

  ln -s "${target_rel}" "${link_path}"
  echo "[setup_lottery_packages] Создан симлинк ${link_path} -> ${target_rel}"
}

ensure_workspace_member() {
  local pkg="$1"
  local workspace_file="${WORKSPACE_ROOT}/Move.toml"

  if [ ! -f "${workspace_file}" ]; then
    echo "[setup_lottery_packages] Пропущено обновление workspace: не найден ${workspace_file}" >&2
    return 1
  fi

  if grep -q "\"${pkg}\"" "${workspace_file}"; then
    return 0
  fi

  python3 - "$workspace_file" "$pkg" <<'PYTHON'
import sys
from pathlib import Path

workspace_file = Path(sys.argv[1])
pkg = sys.argv[2]

text = workspace_file.read_text()
if f'"{pkg}"' in text:
    sys.exit(0)

lines = text.splitlines()
members_start = None
for idx, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith("members") and stripped.endswith("["):
        members_start = idx
        break

if members_start is None:
    print("[setup_lottery_packages] Не удалось найти секцию members в Move.toml", file=sys.stderr)
    sys.exit(1)

closing_idx = None
for idx in range(members_start + 1, len(lines)):
    if lines[idx].strip() == "]":
        closing_idx = idx
        break

if closing_idx is None:
    print("[setup_lottery_packages] Не удалось найти закрывающую скобку секции members", file=sys.stderr)
    sys.exit(1)

if closing_idx == members_start + 1:
    indent = "  "
else:
    first_entry = lines[members_start + 1]
    indent = first_entry[: len(first_entry) - len(first_entry.lstrip())]
    if not indent:
        indent = "  "

lines.insert(closing_idx, f"{indent}\"{pkg}\",")

workspace_file.write_text("\n".join(lines) + ("\n" if text.endswith("\n") else ""))
PYTHON

  echo "[setup_lottery_packages] Добавлен ${pkg} в workspace members"
}

write_move_toml() {
  local pkg="$1"
  local target="${WORKSPACE_ROOT}/${pkg}/Move.toml"

  if [ -f "${target}" ]; then
    update_addresses_block "${pkg}" "${target}"
    return
  fi

  case "${pkg}" in
    lottery_core)
      cat <<'TOML' >"${target}"
[package]
name = "lottery_core"
version = "0.1.0"

[addresses]
std = "0x1"
MoveStdlib = "0x1"
SupraFramework = "0x1"
supra_addr = "0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e"
lottery = "0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0"
lottery_core = "0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0"
vrf_hub = "0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0"
lottery_factory = "0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0"
lottery_owner = "0x103"
lottery_contract = "0x104"
player1 = "0x105"
player2 = "0x106"
player3 = "0x107"
player4 = "0x108"
jackpot_pool = "0x109"
operations_pool = "0x10a"

[dependencies]
MoveStdlib = { git = "https://github.com/Entropy-Foundation/aptos-core.git", subdir = "aptos-move/framework/move-stdlib", rev = "dev" }
SupraFramework = { git = "https://github.com/Entropy-Foundation/aptos-core.git", subdir = "aptos-move/framework/supra-framework", rev = "dev" }
vrf_hub = { local = "../vrf_hub" }
lottery_factory = { local = "../lottery_factory" }
SupraVrf = { local = "../SupraVrf" }
TOML
      ;;
    lottery_support)
      cat <<'TOML' >"${target}"
[package]
name = "lottery_support"
version = "0.1.0"

[addresses]
std = "0x1"
MoveStdlib = "0x1"
SupraFramework = "0x1"
supra_addr = "0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e"
lottery_core = "0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0"
lottery_support = "0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0"
vrf_hub = "0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0"
lottery_factory = "0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0"
lottery_owner = "0x103"
lottery_contract = "0x104"
player1 = "0x105"
player2 = "0x106"
player3 = "0x107"
player4 = "0x108"
jackpot_pool = "0x109"
operations_pool = "0x10a"

[dependencies]
MoveStdlib = { git = "https://github.com/Entropy-Foundation/aptos-core.git", subdir = "aptos-move/framework/move-stdlib", rev = "dev" }
SupraFramework = { git = "https://github.com/Entropy-Foundation/aptos-core.git", subdir = "aptos-move/framework/supra-framework", rev = "dev" }
lottery_core = { local = "../lottery_core" }
TOML
      ;;
    lottery_rewards)
      cat <<'TOML' >"${target}"
[package]
name = "lottery_rewards"
version = "0.1.0"

[addresses]
std = "0x1"
MoveStdlib = "0x1"
SupraFramework = "0x1"
supra_addr = "0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e"
lottery_core = "0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0"
lottery_rewards = "0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0"
vrf_hub = "0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0"
lottery_factory = "0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0"
lottery_owner = "0x103"
lottery_contract = "0x104"
player1 = "0x105"
player2 = "0x106"
player3 = "0x107"
player4 = "0x108"
jackpot_pool = "0x109"
operations_pool = "0x10a"

[dependencies]
MoveStdlib = { git = "https://github.com/Entropy-Foundation/aptos-core.git", subdir = "aptos-move/framework/move-stdlib", rev = "dev" }
SupraFramework = { git = "https://github.com/Entropy-Foundation/aptos-core.git", subdir = "aptos-move/framework/supra-framework", rev = "dev" }
lottery_core = { local = "../lottery_core" }
TOML
      ;;
  esac

  update_addresses_block "${pkg}" "${target}"
  echo "[setup_lottery_packages] Создан ${pkg}/Move.toml"
}

write_module_stub() {
  local pkg="$1"
  local module="$2"
  local file_name="${MODULE_FILES[${pkg}:${module}]}"
  local target="${WORKSPACE_ROOT}/${pkg}/sources/${file_name}"

  if [ -f "${target}" ]; then
    return
  fi

  case "${pkg}:${module}" in
    lottery_core:main_v2)
      cat <<'MOVE' >"${target}"
/// Временная заглушка модуля ядра лотереи.
/// TODO: перенести реализацию из монолита `lottery::main_v2`.
module lottery_core::main_v2 {
    /// Заглушка, чтобы модуль успешно компилировался до переноса кода.
    const TODO_PLACEHOLDER: bool = false;
}
MOVE
      ;;
    lottery_core:instances)
      cat <<'MOVE' >"${target}"
/// Реализация `lottery_core::instances` перенесена из монолита.
/// Заглушка больше не требуется; файл заполняется реальным кодом в репозитории.
module lottery_core::instances {
    /// Этот шаблон остаётся на случай повтора скрипта.
    const TODO_PLACEHOLDER: bool = false;
}
MOVE
      ;;
    lottery_core:rounds)
      cat <<'MOVE' >"${target}"
/// Временная заглушка `lottery_core::rounds`.
/// TODO: перенести реализацию из `lottery::rounds` и адаптировать capability API.
module lottery_core::rounds {
    /// Заглушка для поддержания сборки.
    const TODO_PLACEHOLDER: bool = false;
}
MOVE
      ;;
    lottery_core:operators)
      cat <<'MOVE' >"${target}"
/// Временная заглушка `lottery_core::operators`.
/// Рабочая реализация перенесена в репозиторий; заглушка остаётся для первичной генерации каркаса.
module lottery_core::operators {
    /// Заглушка для поддержания сборки.
    const TODO_PLACEHOLDER: bool = false;
}
MOVE
      ;;
    lottery_core:treasury_v1)
      cat <<'MOVE' >"${target}"
/// Временная заглушка модуля `lottery_core::treasury_v1`.
/// TODO: перенести реализацию из `lottery::treasury_v1` с учётом новой модели capability.
module lottery_core::treasury_v1 {
    /// Заглушка для поддержания сборки.
    const TODO_PLACEHOLDER: bool = false;
}
MOVE
      ;;
    lottery_core:treasury_multi)
      cat <<'MOVE' >"${target}"
/// Временная заглушка `lottery_core::treasury_multi`.
/// TODO: перенести реализацию из `lottery::treasury_multi` и добавить выдачу `MultiTreasuryCap`.
module lottery_core::treasury_multi {
    /// Заглушка для поддержания сборки.
    const TODO_PLACEHOLDER: bool = false;
}
MOVE
      ;;
    lottery_support:history)
      cat <<'MOVE' >"${target}"
/// Временная заглушка `lottery_support::history`.
/// TODO: подключить capability записи истории из `lottery_core::rounds`.
module lottery_support::history {
    use std::signer;

    /// Заглушка для поддержания сборки.
    const TODO_PLACEHOLDER: bool = false;

    /// Временная функция для инициализации capability истории.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    lottery_support:metadata)
      cat <<'MOVE' >"${target}"
/// Временная заглушка `lottery_support::metadata`.
/// TODO: перенести логику реестра метаданных и обновить зависимости на `lottery_core`.
module lottery_support::metadata {
    use std::signer;

    /// Заглушка для поддержания сборки.
    const TODO_PLACEHOLDER: bool = false;

    /// Временная функция для инициализации capability метаданных.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    lottery_support:migration)
      cat <<'MOVE' >"${target}"
/// Временная заглушка `lottery_support::migration`.
/// TODO: перенести миграционные сценарии и интегрировать capability из ядра.
module lottery_support::migration {
    use std::signer;

    /// Заглушка для поддержания сборки.
    const TODO_PLACEHOLDER: bool = false;

    /// Временная функция инициализации capability миграции.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    lottery_rewards:autopurchase)
      cat <<'MOVE' >"${target}"
/// Временная заглушка `lottery_rewards::autopurchase`.
/// TODO: перенести функционал автопокупок и запрос capability у `lottery_core::rounds` и `treasury_v1`.
module lottery_rewards::autopurchase {
    use std::signer;

    /// Scope для доступа автопокупок к ресурсам ядра.
    pub const SCOPE_AUTOPURCHASE: u64 = 10;

    /// Заглушка структуры контроля доступа к capability раундов и казначейства.
    struct AutopurchaseAccess has key { dummy: bool }

    /// Временная функция для ленивой инициализации capability.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    lottery_rewards:jackpot)
      cat <<'MOVE' >"${target}"
/// Временная заглушка `lottery_rewards::jackpot`.
/// TODO: перенести механику джекпота и ограничить доступ `MultiTreasuryCap`.
module lottery_rewards::jackpot {
    use std::signer;

    /// Scope для доступа джекпота к `MultiTreasuryCap`.
    pub const SCOPE_JACKPOT: u64 = 20;

    /// Заглушка структуры контроля джекпота.
    struct JackpotControl has key { dummy: bool }

    /// Временная функция инициализации capability казначейства.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    lottery_rewards:nft_rewards)
      cat <<'MOVE' >"${target}"
/// Временная заглушка `lottery_rewards::nft_rewards`.
/// TODO: перенести NFT-награды и ресурсы бейджей.
module lottery_rewards::nft_rewards {
    use std::signer;

    /// Заглушка структуры контроля NFT-наград.
    struct NftRewardsControl has key { dummy: bool }

    /// Временная функция инициализации capability минтера бейджей.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    lottery_rewards:referrals)
      cat <<'MOVE' >"${target}"
/// Временная заглушка `lottery_rewards::referrals`.
/// TODO: перенести реферальную программу и использовать `MultiTreasuryCap` с нужным scope.
module lottery_rewards::referrals {
    use std::signer;

    /// Scope для доступа реферальной программы к `MultiTreasuryCap`.
    pub const SCOPE_REFERRALS: u64 = 21;

    /// Заглушка структуры контроля рефералов.
    struct ReferralsControl has key { dummy: bool }

    /// Временная функция инициализации capability казначейства.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    lottery_rewards:store)
      cat <<'MOVE' >"${target}"
/// Временная заглушка `lottery_rewards::store`.
/// TODO: перенести магазин наград и ограничить операции `MultiTreasuryCap`.
module lottery_rewards::store {
    use std::signer;

    /// Scope для доступа магазина к `MultiTreasuryCap`.
    pub const SCOPE_STORE: u64 = 22;

    /// Заглушка структуры контроля магазина.
    struct StoreControl has key { dummy: bool }

    /// Временная функция инициализации capability казначейства.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    lottery_rewards:vip)
      cat <<'MOVE' >"${target}"
/// Временная заглушка `lottery_rewards::vip`.
/// TODO: перенести VIP-подписки и привязать их к capability распределения наград.
module lottery_rewards::vip {
    use std::signer;

    /// Scope для доступа VIP-подписок к `MultiTreasuryCap`.
    pub const SCOPE_VIP: u64 = 23;

    /// Заглушка структуры контроля VIP.
    struct VipControl has key { dummy: bool }

    /// Временная функция инициализации capability казначейства.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    *)
      echo "[setup_lottery_packages] Неизвестная комбинация ${pkg}:${module}" >&2
      return 1
      ;;
  esac

  echo "[setup_lottery_packages] Создан ${pkg}/sources/${file_name}"
}

main() {
  for pkg in "${PACKAGES[@]}"; do
    ensure_directories "${pkg}"
    ensure_symlink "${pkg}"
    ensure_workspace_member "${pkg}"
    write_move_toml "${pkg}"

    for module in ${PACKAGE_MODULES[${pkg}]}; do
      write_module_stub "${pkg}" "${module}"
    done
  done
}

main "$@"
