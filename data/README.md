# Данные игры

Все игровые числа живут здесь, а не в коде. Так баланс правится без изменения кода, а значения совпадают со спецификациями.

| Файл | Что внутри | Спецификация |
| --- | --- | --- |
| `player.json` | Движение, выносливость, усталость | [movement-stamina.md](../docs/systems/movement-stamina.md) |
| `comfort.json` | Лагерь и отдых | [comfort.md](../docs/systems/comfort.md) |
| `comfort_items.csv` | Предметы комфорта и их группы | [comfort.md](../docs/systems/comfort.md) |
| `progression.json` | Опыт, уровни, очки развития | [tech-tree.md](../docs/systems/tech-tree.md) |
| `recipe_tree.csv` | Узлы дерева рецептов; открываемые рецепты и требования через `;` | [tech-tree.md](../docs/systems/tech-tree.md) |
| `gathering.json` | Инвентарь, вес, перегруз, корзина, предметы на земле, ритм ударов, радиус взаимодействия, зона появления веток и камней | [gathering.md](../docs/systems/gathering.md) |
| `items.csv` | Предметы: вес, стопка, опыт | [gathering.md](../docs/systems/gathering.md) |
| `resource_nodes.csv` | Объекты в мире; добыча в виде `id:количество` через `;`, `drop_mode`: `per_hit` или `on_last_hit`, пустой `respawn`: объект не восстанавливается. `tool`: основной инструмент, в его ударах считается `hits`; `alt_tools`: другие инструменты через `;` | [gathering.md](../docs/systems/gathering.md) |
| `tools.csv` | Инструменты сбора: сила удара, ритм, множитель выносливости за удар | [gathering.md](../docs/systems/gathering.md) |
| `crafting.json` | Разбор построек и радиус, в котором ставится чертёж | [crafting.md](../docs/systems/crafting.md) |
| `buildings.csv` | Размеры построек в клетках: ширина и высота | [crafting.md](../docs/systems/crafting.md) |
| `recipes.csv` | Рецепты; материалы в виде `id:количество` через `;`, `tools`: инструменты, которые нужны, но не тратятся, `kind`: `item` или `building`, `start`: `1` у стартовых рецептов, доступных без узла | [crafting.md](../docs/systems/crafting.md) |

## Правила

- Ключи совпадают с названиями параметров в спецификациях.
- Поле `_doc` в JSON указывает на спецификацию, откуда взяты значения.
- Таблицы со списками (предметы, рецепты, узлы) хранятся в CSV в кодировке UTF-8.
- У каждого CSV есть файл `<имя>.csv.import` с `importer="keep"`. Без него Godot принимает таблицу за файл переводов и создаёт рядом файлы `.translation`. Новую таблицу добавляешь вместе с таким файлом: в редакторе Godot это «Keep File (No Import)» во вкладке «Импорт».
- Игра читает данные через автозагрузку `GameData`: `GameData.params("player")` для JSON, `GameData.table("items")` для CSV, строки таблицы по `id`.
- Изменил значение после плейтеста? Обнови таблицу параметров в спецификации.
