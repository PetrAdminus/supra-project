import json
import re
from pathlib import Path
from typing import Any, Dict

import pytest


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "docs" / "handbook" / "architecture" / "json" / "lottery_multi_views.schema.json"
EXAMPLE_PATH = ROOT / "docs" / "handbook" / "architecture" / "json" / "examples" / "lottery_multi_view_samples.json"


class SchemaValidationError(AssertionError):
    pass


def _load_schema() -> Dict[str, Any]:
    with SCHEMA_PATH.open("r", encoding="utf-8") as schema_file:
        return json.load(schema_file)


def _load_example() -> Dict[str, Any]:
    with EXAMPLE_PATH.open("r", encoding="utf-8") as example_file:
        return json.load(example_file)


def _resolve_ref(schema: Dict[str, Any], fragment: Dict[str, Any]) -> Dict[str, Any]:
    if "$ref" not in fragment:
        return fragment
    ref = fragment["$ref"]
    if not ref.startswith("#/$defs/"):
        raise SchemaValidationError(f"Неподдерживаемая ссылка: {ref}")
    key = ref.split("/", maxsplit=2)[-1]
    try:
        return schema["$defs"][key]
    except KeyError as exc:
        raise SchemaValidationError(f"Не найдена схема для ссылки {ref}") from exc


def _ensure_type(instance: Any, expected: str) -> None:
    if expected == "object" and not isinstance(instance, dict):
        raise SchemaValidationError(f"Ожидается объект, получено {type(instance)!r}")
    if expected == "array" and not isinstance(instance, list):
        raise SchemaValidationError(f"Ожидается массив, получено {type(instance)!r}")
    if expected == "integer":
        if isinstance(instance, bool) or not isinstance(instance, int):
            raise SchemaValidationError(f"Ожидается целое число, получено {instance!r}")
    if expected == "string" and not isinstance(instance, str):
        raise SchemaValidationError(f"Ожидается строка, получено {type(instance)!r}")
    if expected == "boolean" and not isinstance(instance, bool):
        raise SchemaValidationError(f"Ожидается булево значение, получено {type(instance)!r}")


def _validate(instance: Any, fragment: Dict[str, Any], schema: Dict[str, Any]) -> None:
    fragment = _resolve_ref(schema, fragment)
    schema_type = fragment.get("type")
    if schema_type:
        _ensure_type(instance, schema_type)
    if schema_type == "object":
        properties: Dict[str, Any] = fragment.get("properties", {})
        required = fragment.get("required", [])
        additional = fragment.get("additionalProperties", True)
        for field in required:
            if field not in instance:
                raise SchemaValidationError(f"Отсутствует обязательное поле: {field}")
        for key, value in instance.items():
            if key in properties:
                _validate(value, properties[key], schema)
            elif isinstance(additional, dict):
                _validate(value, additional, schema)
            elif not additional:
                raise SchemaValidationError(f"Неожиданное поле: {key}")
    elif schema_type == "array":
        items = fragment.get("items")
        if items is not None:
            for element in instance:
                _validate(element, items, schema)
    elif schema_type == "integer":
        minimum = fragment.get("minimum")
        maximum = fragment.get("maximum")
        if minimum is not None and instance < minimum:
            raise SchemaValidationError(f"Значение {instance} меньше минимально допустимого {minimum}")
        if maximum is not None and instance > maximum:
            raise SchemaValidationError(f"Значение {instance} больше максимально допустимого {maximum}")
    elif schema_type == "string":
        pattern = fragment.get("pattern")
        if pattern and not re.fullmatch(pattern, instance):
            raise SchemaValidationError(f"Строка {instance!r} не соответствует шаблону {pattern!r}")
    elif schema_type == "boolean":
        # Никаких дополнительных ограничений
        pass


@pytest.mark.parametrize(
    "schema_fragment, payload",
    [
        (pytest.param(_load_schema(), _load_example(), id="lottery_multi_view_samples")),
    ],
)
def test_examples_align_with_schema(schema_fragment: Dict[str, Any], payload: Dict[str, Any]) -> None:
    """Проверяет, что примерные ответы view удовлетворяют JSON Schema."""
    _validate(payload, schema_fragment, schema_fragment)

    views = payload.get("views", {})
    definitions = schema_fragment["properties"]["views"]["properties"]
    for name, view_payload in views.items():
        fragment = definitions.get(name)
        assert fragment is not None, f"Неизвестное view: {name}"
        _validate(view_payload, fragment, schema_fragment)

