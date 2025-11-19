# JSON-схема отчёта `export_move_inventory`

Этот документ фиксирует формат JSON-экспорта, который формирует скрипт `docs/architecture/tools/export_move_inventory.py`.
Схема нужна для автоматизированных проверок карты миграции (`docs/architecture/move_migration_mapping.md`), сопоставления
структур и интеграции отчёта в CI.

## Общий контейнер
| Поле | Тип | Описание |
| --- | --- | --- |
| `schema_version` | number | Версия схемы. Текущее значение — `1`. Позволяет эволюционировать формат без конфликтов. |
| `generated_at` | string | Таймстемп формирования отчёта в ISO 8601 (UTC). |
| `workspace_root` | string | Путь к Move-workspace, относительно которого собирались пакеты. |
| `package_count` | number | Количество пакетов с директориями `sources`. |
| `module_count` | number | Общее количество модулей, включённых в отчёт. |
| `struct_count` | number | Общее количество структур/ресурсов/событий. |
| `packages` | array | Упорядоченный список пакетов с расшифровкой модулей и структур. |

## Структура элемента `packages[]`
| Поле | Тип | Описание |
| --- | --- | --- |
| `package` | string | Имя пакета (название директории в Move-workspace). |
| `module_count` | number | Количество модулей в пакете (подсчитывается автоматически). |
| `struct_count` | number | Количество структур/ресурсов/событий внутри пакета. |
| `modules` | array | Упорядоченный список модулей и их структур. |

## Структура элемента `modules[]`
| Поле | Тип | Описание |
| --- | --- | --- |
| `name` | string | Полностью квалифицированное имя модуля (`address::module`). |
| `source` | string | Путь к исходнику `.move`, из которого извлечены структуры. |
| `structs` | array | Список описаний структур, событий и ресурсов. |

## Структура элемента `structs[]`
| Поле | Тип | Описание |
| --- | --- | --- |
| `category` | string | Тип записи: `Ресурс`, `Событие` или `Структура`. Определяется по `has key` и атрибутам `#[event]`. |
| `name` | string | Имя структуры (включая параметры типа, если они есть). |
| `abilities` | array | Отсортированный список способностей (`key`, `store`, `copy`, `drop`). |
| `fields` | array | Список объектов `{ "name": string, "type": string }` в порядке объявления. |
| `attributes` | array | Сырые атрибуты (например, `#[event]`), сохранённые без дополнительной интерпретации. |

## Пример JSON
```json
{
  "schema_version": 1,
  "generated_at": "2026-02-24T10:15:00+00:00",
  "workspace_root": "SupraLottery/supra/move_workspace",
  "package_count": 15,
  "module_count": 120,
  "struct_count": 840,
  "packages": [
    {
      "package": "lottery_data",
      "module_count": 12,
      "struct_count": 210,
      "modules": [
        {
          "name": "lottery_data::instances",
          "source": "SupraLottery/supra/move_workspace/lottery_data/sources/instances.move",
          "structs": [
            {
              "category": "Ресурс",
              "name": "InstanceRegistry",
              "abilities": ["key"],
              "fields": [
                { "name": "admin", "type": "address" },
                { "name": "lottery_ids", "type": "vector<u64>" }
              ],
              "attributes": []
            }
          ]
        }
      ]
    }
  ]
}
```

Для любых изменений формата увеличивайте `schema_version` и обновляйте этот документ, чтобы инструменты миграции могли своевременно
адаптироваться к новой структуре данных.
