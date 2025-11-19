#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
WORKSPACE_ROOT="${REPO_ROOT}/SupraLottery/supra/move_workspace"
LINK_ROOT="${ROOT_DIR}/move_workspace"
PACKAGES=("lottery_core" "lottery_support" "lottery_rewards")

BASE_PACKAGE_FILE="${WORKSPACE_ROOT}/lottery/Move.toml"

if [ ! -f "${BASE_PACKAGE_FILE}" ]; then
  echo "[setup_lottery_packages] РќРµ РЅР°Р№РґРµРЅ Р±Р°Р·РѕРІС‹Р№ РїР°РєРµС‚ lottery (${BASE_PACKAGE_FILE})" >&2
  exit 1
fi

declare -A PACKAGE_MODULES=(
  [lottery_core]="core_main_v2 core_instances core_rounds core_operators core_treasury_v1 core_treasury_multi"
  [lottery_support]="support_history support_metadata support_migration"
  [lottery_rewards]="rewards_autopurchase rewards_jackpot rewards_nft rewards_referrals rewards_store rewards_vip rewards_rounds_sync"
)

declare -A MODULE_FILES=(
  [lottery_core:core_main_v2]="Lottery.move"
  [lottery_core:core_instances]="LotteryInstances.move"
  [lottery_core:core_rounds]="LotteryRounds.move"
  [lottery_core:core_operators]="Operators.move"
  [lottery_core:core_treasury_v1]="Treasury.move"
  [lottery_core:core_treasury_multi]="TreasuryMulti.move"
  [lottery_support:support_history]="History.move"
  [lottery_support:support_metadata]="Metadata.move"
  [lottery_support:support_migration]="Migration.move"
  [lottery_rewards:rewards_autopurchase]="Autopurchase.move"
  [lottery_rewards:rewards_jackpot]="Jackpot.move"
  [lottery_rewards:rewards_nft]="NftRewards.move"
  [lottery_rewards:rewards_referrals]="Referrals.move"
  [lottery_rewards:rewards_store]="Store.move"
  [lottery_rewards:rewards_vip]="Vip.move"
  [lottery_rewards:rewards_rounds_sync]="RoundsSync.move"
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
except ModuleNotFoundError:  # pragma: no cover - fallback РґР»СЏ Р±РѕР»РµРµ СЃС‚Р°СЂС‹С… Python
    import tomli as tomllib  # type: ignore

if not base_path.exists():
    print(f"[setup_lottery_packages] РќРµ РЅР°Р№РґРµРЅ Р±Р°Р·РѕРІС‹Р№ Move.toml: {base_path}", file=sys.stderr)
    sys.exit(1)

if not target_path.exists():
    print(f"[setup_lottery_packages] РќРµ РЅР°Р№РґРµРЅ С†РµР»РµРІРѕР№ Move.toml: {target_path}", file=sys.stderr)
    sys.exit(1)

data = tomllib.loads(base_path.read_text())
addresses = data.get("addresses")
if not isinstance(addresses, dict) or not addresses:
    print(f"[setup_lottery_packages] Р’ {base_path} РѕС‚СЃСѓС‚СЃС‚РІСѓРµС‚ СЃРµРєС†РёСЏ [addresses]", file=sys.stderr)
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
        print(f"[setup_lottery_packages] Р’ {base_path} РѕС‚СЃСѓС‚СЃС‚РІСѓРµС‚ Р°РґСЂРµСЃ 'lottery'", file=sys.stderr)
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
    echo "[setup_lottery_packages] РџСЂРµРґСѓРїСЂРµР¶РґРµРЅРёРµ: ${link_path} СЃСѓС‰РµСЃС‚РІСѓРµС‚ Рё РЅРµ СЏРІР»СЏРµС‚СЃСЏ СЃРёРјР»РёРЅРєРѕРј." >&2
    return
  fi

  ln -s "${target_rel}" "${link_path}"
  echo "[setup_lottery_packages] РЎРѕР·РґР°РЅ СЃРёРјР»РёРЅРє ${link_path} -> ${target_rel}"
}

ensure_workspace_member() {
  local pkg="$1"
  local workspace_file="${WORKSPACE_ROOT}/Move.toml"

  if [ ! -f "${workspace_file}" ]; then
    echo "[setup_lottery_packages] РџСЂРѕРїСѓС‰РµРЅРѕ РѕР±РЅРѕРІР»РµРЅРёРµ workspace: РЅРµ РЅР°Р№РґРµРЅ ${workspace_file}" >&2
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
    print("[setup_lottery_packages] РќРµ СѓРґР°Р»РѕСЃСЊ РЅР°Р№С‚Рё СЃРµРєС†РёСЋ members РІ Move.toml", file=sys.stderr)
    sys.exit(1)

closing_idx = None
for idx in range(members_start + 1, len(lines)):
    if lines[idx].strip() == "]":
        closing_idx = idx
        break

if closing_idx is None:
    print("[setup_lottery_packages] РќРµ СѓРґР°Р»РѕСЃСЊ РЅР°Р№С‚Рё Р·Р°РєСЂС‹РІР°СЋС‰СѓСЋ СЃРєРѕР±РєСѓ СЃРµРєС†РёРё members", file=sys.stderr)
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

  echo "[setup_lottery_packages] Р”РѕР±Р°РІР»РµРЅ ${pkg} РІ workspace members"
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
    lottery_vrf_gateway = "0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0"
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
    lottery_vrf_gateway = { local = "../lottery_vrf_gateway" }
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
    lottery_vrf_gateway = "0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0"
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
    lottery_vrf_gateway = "0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0"
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
  echo "[setup_lottery_packages] РЎРѕР·РґР°РЅ ${pkg}/Move.toml"
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
    lottery_core:core_main_v2)
      cat <<'MOVE' >"${target}"
/// Р’СЂРµРјРµРЅРЅР°СЏ Р·Р°РіР»СѓС€РєР° РјРѕРґСѓР»СЏ СЏРґСЂР° Р»РѕС‚РµСЂРµРё.
/// TODO: РїРµСЂРµРЅРµСЃС‚Рё СЂРµР°Р»РёР·Р°С†РёСЋ РёР· РјРѕРЅРѕР»РёС‚Р° `lottery::core_main_v2`.
module lottery_core::core_main_v2 {
    /// Р—Р°РіР»СѓС€РєР°, С‡С‚РѕР±С‹ РјРѕРґСѓР»СЊ СѓСЃРїРµС€РЅРѕ РєРѕРјРїРёР»РёСЂРѕРІР°Р»СЃСЏ РґРѕ РїРµСЂРµРЅРѕСЃР° РєРѕРґР°.
    const TODO_PLACEHOLDER: bool = false;
}
MOVE
      ;;
    lottery_core:core_instances)
      cat <<'MOVE' >"${target}"
/// Р РµР°Р»РёР·Р°С†РёСЏ `lottery_core::core_instances` РїРµСЂРµРЅРµСЃРµРЅР° РёР· РјРѕРЅРѕР»РёС‚Р°.
/// Р—Р°РіР»СѓС€РєР° Р±РѕР»СЊС€Рµ РЅРµ С‚СЂРµР±СѓРµС‚СЃСЏ; С„Р°Р№Р» Р·Р°РїРѕР»РЅСЏРµС‚СЃСЏ СЂРµР°Р»СЊРЅС‹Рј РєРѕРґРѕРј РІ СЂРµРїРѕР·РёС‚РѕСЂРёРё.
module lottery_core::core_instances {
    /// Р­С‚РѕС‚ С€Р°Р±Р»РѕРЅ РѕСЃС‚Р°С‘С‚СЃСЏ РЅР° СЃР»СѓС‡Р°Р№ РїРѕРІС‚РѕСЂР° СЃРєСЂРёРїС‚Р°.
    const TODO_PLACEHOLDER: bool = false;
}
MOVE
      ;;
    lottery_core:core_rounds)
      cat <<'MOVE' >"${target}"
/// Р’СЂРµРјРµРЅРЅР°СЏ Р·Р°РіР»СѓС€РєР° `lottery_core::core_rounds`.
/// TODO: РїРµСЂРµРЅРµСЃС‚Рё СЂРµР°Р»РёР·Р°С†РёСЋ РёР· `lottery::rounds` Рё Р°РґР°РїС‚РёСЂРѕРІР°С‚СЊ capability API.
module lottery_core::core_rounds {
    /// Р—Р°РіР»СѓС€РєР° РґР»СЏ РїРѕРґРґРµСЂР¶Р°РЅРёСЏ СЃР±РѕСЂРєРё.
    const TODO_PLACEHOLDER: bool = false;
}
MOVE
      ;;
    lottery_core:core_operators)
      cat <<'MOVE' >"${target}"
/// Р’СЂРµРјРµРЅРЅР°СЏ Р·Р°РіР»СѓС€РєР° `lottery_core::core_operators`.
/// Р Р°Р±РѕС‡Р°СЏ СЂРµР°Р»РёР·Р°С†РёСЏ РїРµСЂРµРЅРµСЃРµРЅР° РІ СЂРµРїРѕР·РёС‚РѕСЂРёР№; Р·Р°РіР»СѓС€РєР° РѕСЃС‚Р°С‘С‚СЃСЏ РґР»СЏ РїРµСЂРІРёС‡РЅРѕР№ РіРµРЅРµСЂР°С†РёРё РєР°СЂРєР°СЃР°.
module lottery_core::core_operators {
    /// Р—Р°РіР»СѓС€РєР° РґР»СЏ РїРѕРґРґРµСЂР¶Р°РЅРёСЏ СЃР±РѕСЂРєРё.
    const TODO_PLACEHOLDER: bool = false;
}
MOVE
      ;;
    lottery_core:core_treasury_v1)
      cat <<'MOVE' >"${target}"
/// Р’СЂРµРјРµРЅРЅР°СЏ Р·Р°РіР»СѓС€РєР° РјРѕРґСѓР»СЏ `lottery_core::core_treasury_v1`.
/// TODO: РїРµСЂРµРЅРµСЃС‚Рё СЂРµР°Р»РёР·Р°С†РёСЋ РёР· `lottery::treasury` СЃ СѓС‡С‘С‚РѕРј РЅРѕРІРѕР№ РјРѕРґРµР»Рё capability.
module lottery_core::core_treasury_v1 {
    /// Р—Р°РіР»СѓС€РєР° РґР»СЏ РїРѕРґРґРµСЂР¶Р°РЅРёСЏ СЃР±РѕСЂРєРё.
    const TODO_PLACEHOLDER: bool = false;
}
MOVE
      ;;
    lottery_core:core_treasury_multi)
      cat <<'MOVE' >"${target}"
/// Р’СЂРµРјРµРЅРЅР°СЏ Р·Р°РіР»СѓС€РєР° `lottery_core::core_treasury_multi`.
/// TODO: РїРµСЂРµРЅРµСЃС‚Рё СЂРµР°Р»РёР·Р°С†РёСЋ РёР· `lottery::treasury_multi` Рё РґРѕР±Р°РІРёС‚СЊ РІС‹РґР°С‡Сѓ `MultiTreasuryCap`.
module lottery_core::core_treasury_multi {
    /// Р—Р°РіР»СѓС€РєР° РґР»СЏ РїРѕРґРґРµСЂР¶Р°РЅРёСЏ СЃР±РѕСЂРєРё.
    const TODO_PLACEHOLDER: bool = false;
}
MOVE
      ;;
    lottery_support:support_history)
      cat <<'MOVE' >"${target}"
/// Р’СЂРµРјРµРЅРЅР°СЏ Р·Р°РіР»СѓС€РєР° `lottery_support::support_history`.
/// TODO: РїРѕРґРєР»СЋС‡РёС‚СЊ capability Р·Р°РїРёСЃРё РёСЃС‚РѕСЂРёРё РёР· `lottery_core::core_rounds`.
module lottery_support::support_history {
    use std::signer;

    /// Р—Р°РіР»СѓС€РєР° РґР»СЏ РїРѕРґРґРµСЂР¶Р°РЅРёСЏ СЃР±РѕСЂРєРё.
    const TODO_PLACEHOLDER: bool = false;

    /// Р’СЂРµРјРµРЅРЅР°СЏ С„СѓРЅРєС†РёСЏ РґР»СЏ РёРЅРёС†РёР°Р»РёР·Р°С†РёРё capability РёСЃС‚РѕСЂРёРё.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    lottery_support:support_metadata)
      cat <<'MOVE' >"${target}"
/// Р’СЂРµРјРµРЅРЅР°СЏ Р·Р°РіР»СѓС€РєР° `lottery_support::support_metadata`.
/// TODO: РїРµСЂРµРЅРµСЃС‚Рё Р»РѕРіРёРєСѓ СЂРµРµСЃС‚СЂР° РјРµС‚Р°РґР°РЅРЅС‹С… Рё РѕР±РЅРѕРІРёС‚СЊ Р·Р°РІРёСЃРёРјРѕСЃС‚Рё РЅР° `lottery_core`.
module lottery_support::support_metadata {
    use std::signer;

    /// Р—Р°РіР»СѓС€РєР° РґР»СЏ РїРѕРґРґРµСЂР¶Р°РЅРёСЏ СЃР±РѕСЂРєРё.
    const TODO_PLACEHOLDER: bool = false;

    /// Р’СЂРµРјРµРЅРЅР°СЏ С„СѓРЅРєС†РёСЏ РґР»СЏ РёРЅРёС†РёР°Р»РёР·Р°С†РёРё capability РјРµС‚Р°РґР°РЅРЅС‹С….
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    lottery_support:support_migration)
      cat <<'MOVE' >"${target}"
/// Р’СЂРµРјРµРЅРЅР°СЏ Р·Р°РіР»СѓС€РєР° `lottery_support::support_migration`.
/// TODO: РїРµСЂРµРЅРµСЃС‚Рё РјРёРіСЂР°С†РёРѕРЅРЅС‹Рµ СЃС†РµРЅР°СЂРёРё Рё РёРЅС‚РµРіСЂРёСЂРѕРІР°С‚СЊ capability РёР· СЏРґСЂР°.
module lottery_support::support_migration {
    use std::signer;

    /// Р—Р°РіР»СѓС€РєР° РґР»СЏ РїРѕРґРґРµСЂР¶Р°РЅРёСЏ СЃР±РѕСЂРєРё.
    const TODO_PLACEHOLDER: bool = false;

    /// Р’СЂРµРјРµРЅРЅР°СЏ С„СѓРЅРєС†РёСЏ РёРЅРёС†РёР°Р»РёР·Р°С†РёРё capability РјРёРіСЂР°С†РёРё.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    lottery_rewards:rewards_autopurchase)
      cat <<'MOVE' >"${target}"
/// Р’СЂРµРјРµРЅРЅР°СЏ Р·Р°РіР»СѓС€РєР° `lottery_rewards::rewards_autopurchase`.
/// TODO: РїРµСЂРµРЅРµСЃС‚Рё С„СѓРЅРєС†РёРѕРЅР°Р» Р°РІС‚РѕРїРѕРєСѓРїРѕРє Рё Р·Р°РїСЂРѕСЃ capability Сѓ `lottery_core::core_rounds` Рё `treasury`.
module lottery_rewards::rewards_autopurchase {
    use std::signer;

    /// Scope РґР»СЏ РґРѕСЃС‚СѓРїР° Р°РІС‚РѕРїРѕРєСѓРїРѕРє Рє СЂРµСЃСѓСЂСЃР°Рј СЏРґСЂР°.
    pub const SCOPE_AUTOPURCHASE: u64 = 10;

    /// Р—Р°РіР»СѓС€РєР° СЃС‚СЂСѓРєС‚СѓСЂС‹ РєРѕРЅС‚СЂРѕР»СЏ РґРѕСЃС‚СѓРїР° Рє capability СЂР°СѓРЅРґРѕРІ Рё РєР°Р·РЅР°С‡РµР№СЃС‚РІР°.
    struct AutopurchaseAccess has key { dummy: bool }

    /// Р’СЂРµРјРµРЅРЅР°СЏ С„СѓРЅРєС†РёСЏ РґР»СЏ Р»РµРЅРёРІРѕР№ РёРЅРёС†РёР°Р»РёР·Р°С†РёРё capability.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    lottery_rewards:rewards_jackpot)
      cat <<'MOVE' >"${target}"
/// Р’СЂРµРјРµРЅРЅР°СЏ Р·Р°РіР»СѓС€РєР° `lottery_rewards::rewards_jackpot`.
/// TODO: РїРµСЂРµРЅРµСЃС‚Рё РјРµС…Р°РЅРёРєСѓ РґР¶РµРєРїРѕС‚Р° Рё РѕРіСЂР°РЅРёС‡РёС‚СЊ РґРѕСЃС‚СѓРї `MultiTreasuryCap`.
module lottery_rewards::rewards_jackpot {
    use std::signer;

    /// Scope РґР»СЏ РґРѕСЃС‚СѓРїР° РґР¶РµРєРїРѕС‚Р° Рє `MultiTreasuryCap`.
    pub const SCOPE_JACKPOT: u64 = 20;

    /// Р—Р°РіР»СѓС€РєР° СЃС‚СЂСѓРєС‚СѓСЂС‹ РєРѕРЅС‚СЂРѕР»СЏ РґР¶РµРєРїРѕС‚Р°.
    struct JackpotControl has key { dummy: bool }

    /// Р’СЂРµРјРµРЅРЅР°СЏ С„СѓРЅРєС†РёСЏ РёРЅРёС†РёР°Р»РёР·Р°С†РёРё capability РєР°Р·РЅР°С‡РµР№СЃС‚РІР°.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    lottery_rewards:rewards_nft)
      cat <<'MOVE' >"${target}"
/// Р’СЂРµРјРµРЅРЅР°СЏ Р·Р°РіР»СѓС€РєР° `lottery_rewards::rewards_nft`.
/// TODO: РїРµСЂРµРЅРµСЃС‚Рё NFT-РЅР°РіСЂР°РґС‹ Рё СЂРµСЃСѓСЂСЃС‹ Р±РµР№РґР¶РµР№.
module lottery_rewards::rewards_nft {
    use std::signer;

    /// Р—Р°РіР»СѓС€РєР° СЃС‚СЂСѓРєС‚СѓСЂС‹ РєРѕРЅС‚СЂРѕР»СЏ NFT-РЅР°РіСЂР°Рґ.
    struct NftRewardsControl has key { dummy: bool }

    /// Р’СЂРµРјРµРЅРЅР°СЏ С„СѓРЅРєС†РёСЏ РёРЅРёС†РёР°Р»РёР·Р°С†РёРё capability РјРёРЅС‚РµСЂР° Р±РµР№РґР¶РµР№.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    lottery_rewards:rewards_referrals)
      cat <<'MOVE' >"${target}"
/// Р’СЂРµРјРµРЅРЅР°СЏ Р·Р°РіР»СѓС€РєР° `lottery_rewards::rewards_referrals`.
/// TODO: РїРµСЂРµРЅРµСЃС‚Рё СЂРµС„РµСЂР°Р»СЊРЅСѓСЋ РїСЂРѕРіСЂР°РјРјСѓ Рё РёСЃРїРѕР»СЊР·РѕРІР°С‚СЊ `MultiTreasuryCap` СЃ РЅСѓР¶РЅС‹Рј scope.
module lottery_rewards::rewards_referrals {
    use std::signer;

    /// Scope РґР»СЏ РґРѕСЃС‚СѓРїР° СЂРµС„РµСЂР°Р»СЊРЅРѕР№ РїСЂРѕРіСЂР°РјРјС‹ Рє `MultiTreasuryCap`.
    pub const SCOPE_REFERRALS: u64 = 21;

    /// Р—Р°РіР»СѓС€РєР° СЃС‚СЂСѓРєС‚СѓСЂС‹ РєРѕРЅС‚СЂРѕР»СЏ СЂРµС„РµСЂР°Р»РѕРІ.
    struct ReferralsControl has key { dummy: bool }

    /// Р’СЂРµРјРµРЅРЅР°СЏ С„СѓРЅРєС†РёСЏ РёРЅРёС†РёР°Р»РёР·Р°С†РёРё capability РєР°Р·РЅР°С‡РµР№СЃС‚РІР°.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    lottery_rewards:rewards_store)
      cat <<'MOVE' >"${target}"
/// Р’СЂРµРјРµРЅРЅР°СЏ Р·Р°РіР»СѓС€РєР° `lottery_rewards::rewards_store`.
/// TODO: РїРµСЂРµРЅРµСЃС‚Рё РјР°РіР°Р·РёРЅ РЅР°РіСЂР°Рґ Рё РѕРіСЂР°РЅРёС‡РёС‚СЊ РѕРїРµСЂР°С†РёРё `MultiTreasuryCap`.
module lottery_rewards::rewards_store {
    use std::signer;

    /// Scope РґР»СЏ РґРѕСЃС‚СѓРїР° РјР°РіР°Р·РёРЅР° Рє `MultiTreasuryCap`.
    pub const SCOPE_STORE: u64 = 22;

    /// Р—Р°РіР»СѓС€РєР° СЃС‚СЂСѓРєС‚СѓСЂС‹ РєРѕРЅС‚СЂРѕР»СЏ РјР°РіР°Р·РёРЅР°.
    struct StoreControl has key { dummy: bool }

    /// Р’СЂРµРјРµРЅРЅР°СЏ С„СѓРЅРєС†РёСЏ РёРЅРёС†РёР°Р»РёР·Р°С†РёРё capability РєР°Р·РЅР°С‡РµР№СЃС‚РІР°.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    lottery_rewards:rewards_vip)
      cat <<'MOVE' >"${target}"
/// Р’СЂРµРјРµРЅРЅР°СЏ Р·Р°РіР»СѓС€РєР° `lottery_rewards::rewards_vip`.
/// TODO: РїРµСЂРµРЅРµСЃС‚Рё VIP-РїРѕРґРїРёСЃРєРё Рё РїСЂРёРІСЏР·Р°С‚СЊ РёС… Рє capability СЂР°СЃРїСЂРµРґРµР»РµРЅРёСЏ РЅР°РіСЂР°Рґ.
module lottery_rewards::rewards_vip {
    use std::signer;

    /// Scope РґР»СЏ РґРѕСЃС‚СѓРїР° VIP-РїРѕРґРїРёСЃРѕРє Рє `MultiTreasuryCap`.
    pub const SCOPE_VIP: u64 = 23;

    /// Р—Р°РіР»СѓС€РєР° СЃС‚СЂСѓРєС‚СѓСЂС‹ РєРѕРЅС‚СЂРѕР»СЏ VIP.
    struct VipControl has key { dummy: bool }

    /// Р’СЂРµРјРµРЅРЅР°СЏ С„СѓРЅРєС†РёСЏ РёРЅРёС†РёР°Р»РёР·Р°С†РёРё capability РєР°Р·РЅР°С‡РµР№СЃС‚РІР°.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
MOVE
      ;;
    *)
      echo "[setup_lottery_packages] РќРµРёР·РІРµСЃС‚РЅР°СЏ РєРѕРјР±РёРЅР°С†РёСЏ ${pkg}:${module}" >&2
      return 1
      ;;
  esac

  echo "[setup_lottery_packages] РЎРѕР·РґР°РЅ ${pkg}/sources/${file_name}"
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


