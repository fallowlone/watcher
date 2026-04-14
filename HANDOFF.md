# Что сделано сегодня

- Buffer / Blob / FormData -- тема закрыта
- Event loop deep dive -- тема закрыта
- VirusTotal polling -- исправлен порядок (delay перед запросом)
- id: "string" -- исправлен литеральный тип
- Docker -- Dockerfile написан, образ собран
- ConfigManager -- удалён, заменён на process.env
- package.json -- добавлен start:local скрипт
- .env.docker -- создан для Docker запуска
- FileMover -- rename заменён на copyFile + unlink (EXDEV fix)
- Проект работает end-to-end в Docker

## Текущее состояние: проект полностью работает локально и в Docker контейнере

## Следующие шаги

1. prototype chain + extends -- последний knowledge debt
2. Backend Concepts -- HTTP/1 vs HTTP/2 (entry point Phase 1b)

## Открытые вопросы

Может ли вирус запуститься до перемещения файла (запарковано)
