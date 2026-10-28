# Данные игры

Все игровые числа живут здесь, а не в коде. Так баланс правится без изменения кода, а значения совпадают со спецификациями.

| Файл | Что внутри | Спецификация |
| --- | --- | --- |
| `player.json` | Движение, выносливость, усталость | [movement-stamina.md](../docs/systems/movement-stamina.md) |
| `comfort.json` | Лагерь и отдых | [comfort.md](../docs/systems/comfort.md) |
| `comfort_items.csv` | Предметы комфорта и их группы | [comfort.md](../docs/systems/comfort.md) |
| `progression.json` | Опыт, уровни, очки развития | [tech-tree.md](../docs/systems/tech-tree.md) |
| `recipe_tree.csv` | Узлы дерева рецептов; требования через `;` | [tech-tree.md](../docs/systems/tech-tree.md) |
| `gathering.json` | Инвентарь, вес, перегруз | [gathering.md](../docs/systems/gathering.md) |
| `items.csv` | Предметы: вес, стопка, опыт | [gathering.md](../docs/systems/gathering.md) |
| `resource_nodes.csv` | Объекты в мире; добыча в виде `id:количество` через `;`, `drop_mode`: `per_hit` или `on_last_hit` | [gathering.md](../docs/systems/gathering.md) |

## Правила

- Ключи совпадают с названиями параметров в спецификациях.
- Поле `_doc` в JSON указывает на спецификацию, откуда взяты значения.
- Таблицы со списками (предметы, рецепты, узлы) хранятся в CSV в кодировке UTF-8.
- Изменил значение после плейтеста? Обнови таблицу параметров в спецификации.
