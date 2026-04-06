# План внедрения геймификации (GymMore / FitFlow)

Документ описывает поэтапное внедрение production-ready слоя наград в существующее приложение. Целевой продукт: **GymMore** (gymmore.ru); Dart-пакет клиента: **`fitflow`** (`mobile/pubspec.yaml`). Репозиторий бэкенда: модульный монолит **`github.com/fitflow/fitflow`** (`fitapp/internal/...`).

Принципы:

- не ломать текущую архитектуру (clean architecture, домены по границам модулей);
- инкрементальные изменения, feature flags на этапе раскатки;
- геймификация — **надстройка**: не блокировать завершение/старт тренировки и сценарии тренера;
- старт тренировки остаётся по возможности ≤ 2 тапов от привычного входа.

---

## Текущее состояние проекта (аудит)

| Область | Состояние |
|--------|-----------|
| Модуль геймификации на клиенте | **Отсутствует** — нет `lib/features/gamification/`. |
| Модуль геймификации на сервере | **Отсутствует** — в `internal/` нет домена XP/бейджей/миссий. |
| State management | **Riverpod** (`flutter_riverpod`, `riverpod_annotation`) — планировать провайдеры, не Bloc. |
| Навигация | **go_router** — новые экраны добавлять в `mobile/lib/core/router/app_router.dart`. |
| Соц. лента, тренировки, прогресс, тренер, групповые | Реализованы и завязаны на REST `/api/v1` (см. `internal/delivery/http/routes.go`). |
| Уведомления | API `/me/notifications`, Redis; push — по проекту на уровне placeholder/расширения — хуки для напоминаний миссий задать в общем контракте. |
| Feature flags в приложении | **Нет единого механизма** — флаги из плана нужно ввести (локально + опционально поле в профиле/конфиге с сервера). |

Неточности исходного черновика, которые исправлены здесь:

- Продукт в описании клиента — **GymMore**; в коде импорты — `package:fitflow/...`, не `gymmore`.
- Роуты перечислены неполно: есть **`/loading`**, **`/login`**, **`/register`**, **`/system-messages`**, **`/help`**, **`/help/:topicId`**, вложенные **`/progress/*`**, **`/templates/*`**, **`/trainer/group-training-templates`**, **`/trainer/group-trainings`**, публичные **`/t/:userId`**, **`/g/:trainingId`** (без обязательного логина).
- Режимы **«спортсмен» / «я тренер»** переключаются в drawer (`MainShellScreen`), а не только отдельными URL.
- Экран **`HomeScreen`** по пути `/` в роутере — отдельная «меню-страница»; основной список тренировок — **`/home`** (`WorkoutsListScreen` внутри shell). При внедрении виджетов геймификации на «домашний» список тренировок ориентироваться на **`/home`** и `workouts_list_screen.dart`, а не на устаревшие ссылки вроде несуществующего в роутере `/workouts` (если не добавлен отдельный маршрут).

---

## Целевая функциональность геймификации

1. Система XP  
2. Уровни  
3. Прогресс «аватара» (косметика / визуальные ступени)  
4. Бейджи (achievements)  
5. Стена коллекций (badges)  
6. Миссии (ежедневные и еженедельные)  
7. Социальный лидерборд  
8. Лидерборд по залу  
9. Лидерборд среди тренеров / клиентов тренера (по политике продукта)  
10. Модалка level-up  
11. Анимации наград (лёгкие)  
12. Шаринг в **`/feed`** (посты о достижениях)  
13. Напоминания (push / локальные) — через существующий контур уведомлений  
14. Достижения, связанные с **групповыми тренировками**

Ограничения UX: не усложнять критический путь тренировки и тренерских сценариев.

---

## Этап 1 — Domain + data (Flutter)

Новый feature module: `mobile/lib/features/gamification/`.

**Сущности (entities):** `gamification_profile.dart`, `xp_event.dart`, `badge.dart`, `mission.dart`, `leaderboard_entry.dart`, `level_reward.dart`.

**Репозиторий:** `gamification_repository.dart` — абстракция над REST (см. backend ниже).

**Сервисы (чистая логика + при необходимости кэш):** `xp_calculation_service.dart` (дублировать правила с сервера только для UI-превью; источник истины — API), `badge_unlock_service.dart`, `level_service.dart`, `mission_engine.dart`.

**Состояние:** Riverpod — `gamification_provider.dart` (и при необходимости codegen).

**Feature flags (ввести в проект):** `xp_enabled`, `badges_enabled`, `leaderboard_enabled`, `trainer_ranking_enabled` — хранение: например `SharedPreferences` + опционально снимок с `GET /me` или отдельный endpoint конфигурации.

**Backend:** см. раздел [Backend: домен и API](#backend-домен-и-api) — без серверной части этап 1 на клиенте ограничен моками.

---

## Этап 2 — Post workout reward flow

Интеграция после завершения тренировки:

- Точка входа UI: экран статистики **`/workout/:id/stats`** (`workout_stats_screen.dart`) и/или возврат с **`PATCH .../finish`** на клиенте.
- Поток: начисление XP (подтверждение с сервера) → level up → бейджи → миссии → модалка награды.

**UI (примеры имён виджетов):** `earned_xp_card.dart`, `level_up_modal.dart`, `badge_unlock_popup.dart`, `confetti_overlay.dart`.

UX: модалка не блокирует системный back; dismiss (в т.ч. swipe down); CTA «Продолжить».

---

## Этап 3 — Интеграция с «домом»

Обновить **`/home`** (`WorkoutsListScreen`): полоса XP, мини-аватар уровня, активная daily mission, мини-лидерборд — **над** списком тренировок, через slivers при прокрутке, не ломая список.

---

## Этап 4 — Раздел Progress

Расширить **`/progress`**: подпункты Achievements, Missions, Leaderboard, XP history.

**Новые маршруты (добавить в `app_router`):**

- `/progress/achievements`  
- `/progress/missions`  
- `/progress/leaderboard`  
- `/progress/xp-history`  

Экраны: `achievements_screen.dart`, `missions_screen.dart`, `leaderboard_screen.dart`, `xp_history_screen.dart`. Стена коллекций: locked/unlocked, редкость, CTA «поделиться».

---

## Этап 5 — Лента

Интеграция с **`/feed`**: тип карточки достижения (`achievement_feed_card.dart`), опциональный share после level up. Использовать существующий API постов (`POST /me/posts` и т.д.) — уточнить формат payload для типа «achievement» при реализации backend/контракта.

---

## Этап 6 — Тренер

Маршруты (новые, согласовать с `go_router`):

- `/trainer/rankings`  
- `/trainer/achievements`  

Виджеты в сценариях **`/trainer/trainees`**, **`/trainer/group-trainings`**, **`/trainer/profile`**: например `trainer_rank_card.dart`, `trainee_success_meter.dart`, `group_achievement_banner.dart`.

События XP продукта (пример): завершение тренировки подопечным, проведение группового занятия, метрики удержания — **фиксировать на сервере**, клиент только отображает.

---

## Этап 7 — Групповые тренировки и залы

Точки интеграции: **`/group-trainings`**, **`/group-trainings/available`**, **`/gym/:gymId`**. Лидерборд зала, топ посещаемости, streak, бейджи событий — зависят от агрегатов на backend и привязки к `gym_id` / регистрациям (см. ниже).

---

## Этап 8 — Аналитика и раскатка

События (Firebase/свой аналитический слой / логи): `xp_earned`, `level_up`, `badge_unlocked`, `daily_mission_completed`, `weekly_streak_updated`, `workout_repeat_after_reward`, `trainer_rank_up`, `trainee_goal_completed`, `leaderboard_open`, `share_achievement`.

Фазы rollout (как ориентир):

1. XP + награды за тренировку  
2. Бейджи + миссии  
3. Лидерборды + соц. шаринг  
4. Ранги тренера и зала  

---

# Backend: домен и API

Ниже — план серверной части в терминах текущего монолита **FitFlow** (`cmd/api`, `internal/*/domain`, `migrations`).

## 1. Новый модуль

Рекомендуемое имя пакета: **`internal/gamification/`** (или `rewards`) со слоями:

- `domain/` — сущности, правила начисления, идемпотентные ключи событий  
- `repository/` — PostgreSQL  
- `usecase/` — начисление XP, выдача бейджей, прогресс миссий, пересчёт лидербордов  
- `delivery/http/` — хендлеры, регистрация в `internal/delivery/http/routes.go`  

Зависимости: существующие модули **workout** (факт завершения), **user**, **gym** (привязка к залу), **grouptraining** (регистрация/посещение), **social** (опционально — создание поста-обёртки), **notification** (напоминания).

## 2. Данные (PostgreSQL) — черновая схема

Миграции с UUID PK, `created_at`/`updated_at`, индексы по `user_id`, `created_at`.

| Таблица / сущность | Назначение |
|--------------------|------------|
| `gamification_profiles` | `user_id`, `total_xp`, `current_level`, `avatar_tier` (или ссылка на косметику), `updated_at` |
| `xp_ledger` | Журнал: `id`, `user_id`, `delta_xp`, `reason` (enum), `source_type` (workout, mission, group_training, …), `source_id` (UUID nullable), `idempotency_key` **unique**, `created_at` |
| `badge_definitions` | Каталог бейджей: код, название, описание, редкость, условие (JSON или отдельные поля) |
| `user_badges` | `user_id`, `badge_id`, `unlocked_at`, опционально `meta` JSON |
| `mission_definitions` | Ежедневные/еженедельные шаблоны |
| `user_mission_state` | Прогресс по миссии, окно дат, статус |
| `leaderboard_snapshots` или материализованное представление | Период (день/неделя), тип (global, gym, trainer_clients), ранг — либо считать on-the-fly с кэшем Redis |

**Идемпотентность:** при начислении за `workout_id` использовать ключ вида `xp:workout:{workout_id}` в `xp_ledger`, чтобы повторный `finish` не удваивал XP.

## 3. REST API (префикс `/api/v1`, JWT)

Группа под существующим `middleware.JWTAuth`:

- `GET /me/gamification/profile` — профиль, уровень, XP до следующего уровня  
- `GET /me/gamification/xp-history` — пагинация по `xp_ledger`  
- `GET /me/gamification/badges` — разблокированные + при необходимости каталог с флагом locked  
- `GET /me/gamification/missions` — активные миссии и прогресс  
- `POST /me/gamification/missions/:id/claim` — забрать награду, если предусмотрено  
- `GET /me/gamification/leaderboards` — query: `scope=global|gym|trainer`, `period=week`, `gym_id`, …  

Публичные (опционально, для шаринга):

- `GET /gamification/leaderboards/public` — урезанный топ без PII.

Админка (`/admin`): CRUD для `badge_definitions`, `mission_definitions`, коэффициентов XP (если не в коде).

## 4. Точки интеграции в бизнес-логике (сервер)

| Событие | Где вызывать |
|---------|----------------|
| Тренировка завершена | После успешного `FinishWorkout` в `workout` use case — вызов `gamification.ApplyWorkoutCompleted(ctx, userID, workoutID, meta)` |
| Групповая тренировка | После регистрации/посещения/отмены — по правилам продукта в `grouptraining` use case |
| Чек-ин в зале | Опционально для миссий «N визитов в зал» — `gym` check-in |

Предпочтительно **синхронный вызов use case геймификации из одной транзакции** с завершением тренировки либо **outbox / событие** в той же БД для последующей обработки worker’ом — выбрать по нагрузке; для MVP достаточно вызова в том же запросе с короткой логикой.

## 5. Лидерборды

- **Вариант A:** Redis `ZADD` по ключам `lb:global:week:{iso_week}`, обновление при начислении XP — быстрый топ-N.  
- **Вариант B:** только PostgreSQL + периодический job пересчёта — проще эксплуатация, медленнее на больших объёмах.

Для **gym** — участники только с `gym_id` из профиля/чек-инов; уточнить продуктово.

## 6. Уведомления и push

Расширить типы payload в модуле **notification** (или шаблоны): «миссия почти выполнена», «ежедневная награда», «вас обогнали в лидерборде». Реальная доставка push зависит от текущей реализации — в плане заложить **событие** и **запись в БД уведомления**.

## 7. OpenAPI и контракт с Flutter

Добавить пути в `docs/openapi.yaml` / `internal/delivery/http/spec` после стабилизации DTO.

## 8. Тестирование на backend

Unit-тесты use case: идемпотентность XP, порог level up, выдача бейджа один раз. Интеграционные: завершение тренировки → запись в `xp_ledger`.

---

## Технические требования (кросс-срез)

1. Следовать структуре `mobile/lib/features/*` и `internal/*`.  
2. Использовать дизайн-токены/тему приложения.  
3. Виджеты модульные; тяжёлые экраны тренировки не перестраивать без нужды.  
4. Кэш лидерборда на клиенте с TTL; на сервере — кэш/Redis по политике.  
5. Лёгкие анимации.  
6. DTO для всех новых endpoint’ов; **источник истины по XP/уровням — сервер**.

---

## Формат работ по этапам (для команды)

Для каждого этапа: анализ кода → список файлов → реализация → риски миграции → тесты → флаг раскатки → ревью.

---

*Обновлено по состоянию репозитория: домен геймификации отсутствует; клиент на Riverpod + go_router; маршруты сверены с `app_router.dart` и `routes.go`.*
