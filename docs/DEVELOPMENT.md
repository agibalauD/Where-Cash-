# Разработка и сборка

## Требования

- macOS 14 или новее;
- Xcode 26.2 или совместимая версия с SDK macOS 14+;
- Swift 5 language mode;
- интернет для получения курса НБ РБ и работы Telegram-бота.

Внешние Swift Packages отсутствуют. Telegram-интеграция использует стандартный `URLSession` и официальный HTTPS Bot API.

## Структура

```text
WhereCash.xcodeproj/       Xcode-проект и общая схема
WhereCash/
  Models/                  SwiftData и доменные перечисления
  Services/                курс, расчёты, автозапуск, Keychain и Telegram
  Utilities/               ввод, форматирование, календарь
  Views/                   SwiftUI-представления и PanelRouter
  WhereCashApp.swift       AppDelegate, NSStatusItem и композиция зависимостей
WhereCashTests/            XCTest unit-тесты
docs/                      документация
dist/                      локальная неподписанная сборка
```

## Xcode

Откройте `WhereCash.xcodeproj`, выберите схему `WhereCash` и назначение `My Mac`. Проект использует bundle identifier `com.wherecash.desktop`, минимальную версию macOS 14.0 и генерируемый Info.plist.

`LSUIElement=YES` обязателен: без него приложение появится в Dock. App Sandbox для тестовой версии выключен. Перед публикацией потребуется отдельно включить sandbox, настроить network entitlement, Developer ID и notarization.

Элемент строки меню реализован через AppKit `NSStatusItem`, потому что панель и контекстное меню имеют разные действия мыши. `StatusBarController` должен оставаться тонким слоем: навигация выполняется через `PanelRouter`, а содержимое разделов остаётся в SwiftUI. Локальный и глобальный мониторы мыши создаются только на время показа popover и обязательно удаляются в `popoverDidClose`.

## Командная сборка

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project WhereCash.xcodeproj \
  -scheme WhereCash \
  -configuration Debug \
  -derivedDataPath /tmp/WhereCashDerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

Готовый продукт появится в `/tmp/WhereCashDerivedData/Build/Products/Debug/WhereCash.app`.

## Тесты

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project WhereCash.xcodeproj \
  -scheme WhereCash \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/WhereCashDerivedData \
  CODE_SIGNING_ALLOWED=NO
```

Перед любым новым циклом проверки необходимо спросить пользователя, требуются ли дополнительные изображения, тексты или документы.

## Правила изменений

- Денежные значения хранить в `Int64` как минимальные единицы.
- Не выполнять валютные расчёты непосредственно во View.
- Не переименовывать raw values категорий без миграции SwiftData; расходные расчёты должны использовать `spendingCases`, а не `allCases`.
- Новые пользовательские настройки добавлять через стабильные ключи `AppSettingKeys`.
- Новые разделы панели добавлять в `PanelSection` и открывать через `PanelRouter`.
- Не переносить бизнес-логику в `StatusBarController`; он отвечает только за системный элемент, popover и контекстное меню.
- Никогда не хранить и не логировать Telegram-токен в `UserDefaults`, документации или исходном коде; используется только `KeychainService`.
- Keychain-запись Telegram использует `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`: токен не должен переноситься через резервную копию или синхронизироваться на другое устройство.
- Перед публикацией выполнять поиск секретов; каталоги сборок, SwiftData-базы, `.env`, сертификаты и закрытые ключи не включать в Git.
- Telegram `update_id` сохранять после обработки обновления, чтобы избежать повторного создания расходов.
- Telegram-статистика всегда строится для `Date()`; месячную навигацию и архивные callback-команды в бот не добавлять.
- PNG-карточка должна получать значения из `ExpenseCalculator` и `SavingsCalculator`, а не повторять валютные формулы внутри `TelegramStatisticsRenderer`.
- Основные кнопки Telegram реализуются через `ReplyKeyboardMarkup` с `is_persistent=true`; валюты и категории остаются одноразовыми inline-кнопками с callback-данными.
- Категория `savings` должна создавать `SavingsContribution`, а не `ExpenseRecord`; без выбранной цели запись запрещена.
- Пополнение в отличной от цели валюте требует текущего или кэшированного курса. Валюта цели блокируется после первого пополнения.
- Удаление цели должно удалять связанные пополнения и очищать `selectedSavingsGoalID`, если удалена выбранная цель.
- Внутри `NSPopover` подтверждения действий не должны открываться через системный `confirmationDialog`: его отдельное AppKit-окно воспринимается монитором внешних кликов как нажатие вне панели. Используется единый SwiftUI `overlay` внутри панели. Удаляемые SwiftData-модели нельзя удерживать в `@State`: хранится UUID, а состояние презентации очищается до мутации контекста.
- Callback-кнопки должны содержать идентификатор активной сессии и укладываться в лимит Telegram `callback_data`.
- Изменение модели `ExpenseRecord` сопровождать планом миграции и тестом существующих данных.
- Для новых правил расчёта добавлять unit-тесты до изменения интерфейса.
- Документацию обновлять в том же изменении, что и поведение.

## Подготовка к распространению

Текущая сборка предназначена для тестирования. Для передачи обычным пользователям потребуется:

1. Apple Developer Account и Developer ID Application certificate.
2. Уникальный bundle identifier, принадлежащий владельцу аккаунта.
3. Включение App Sandbox и исходящего сетевого доступа.
4. Archive, подпись, notarization и упаковка в DMG.
5. Проверка автозапуска уже подписанной сборки.
