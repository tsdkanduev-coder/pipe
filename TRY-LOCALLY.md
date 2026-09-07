# PIP — локальный прогон

Форк Dayflow. Ставится рядом с Dayflow, данные не смешиваются.

- Приложение: `PIP.app`, bundle `app.pip.macos`
- Данные: `~/Library/Application Support/PIP`
- Модель по умолчанию: локальный `qwen3.5:4b` через Ollama
- Агентам: MCP-сервер `pipe` и HTTP `http://127.0.0.1:8787`

## Что нужно

- Mac с Apple Silicon
- Xcode
- [Ollama](https://ollama.com) — поставить и оставить запущенной

## Модель Qwen

PIP **не** кладёт модель в репозиторий. Она живёт в Ollama.

1. Поставь Ollama и открой её, чтобы демон слушал `127.0.0.1:11434`.
2. При первом запуске PIP сам делает `ollama pull qwen3.5:4b` (~3.4 GB), если Ollama уже доступна. В окне PIP прогресса не будет — это фон.
3. Если Ollama не была запущена в этот момент, скачай модель руками:

```bash
ollama pull qwen3.5:4b
```

Проверка:

```bash
ollama list
```

В списке должна быть `qwen3.5:4b`. Без неё лента не соберётся: запись экрана идёт, карточек нет.

## Собрать и запустить

```bash
git clone https://github.com/tsdkanduev-coder/pipe.git
cd pipe

xcodebuild \
  -project Dayflow/Dayflow.xcodeproj \
  -scheme Dayflow \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/xcode \
  -skip-testing \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  DEVELOPMENT_TEAM=""

rm -rf /Applications/PIP.app
cp -R .build/xcode/Build/Products/Release/PIP.app /Applications/PIP.app
xattr -cr /Applications/PIP.app
codesign --force --deep --sign - /Applications/PIP.app
open /Applications/PIP.app
```

## После запуска

1. Разреши **Screen Recording** именно для **PIP**, не для Dayflow.
2. Убедись, что Ollama запущена. Если модели ещё нет — `ollama pull qwen3.5:4b`.
3. Оставь PIP включённым. Первые карточки появляются примерно через 15 минут записи.
4. В Settings → **MCP / CLI** нажми Connect у MultiTool / Cursor / Codex.

Проверка, что HTTP жив:

```bash
curl -sS http://127.0.0.1:8787/v1/status
curl -sS http://127.0.0.1:8787/v1/context
```

Dayflow, если установлен, не трогай. У него своё приложение и своя папка данных.
