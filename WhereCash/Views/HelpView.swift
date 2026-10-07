import SwiftUI

struct HelpView: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: onBack) {
                    Label("Назад", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Помощь")
                    .font(.title3.bold())

                Spacer()

                Color.clear.frame(width: 52, height: 1)
            }
            .padding(.horizontal)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HelpSection(
                        symbol: "plus.circle.fill",
                        title: "Добавление расхода",
                        text: "Введите положительную сумму в нижней части панели, выберите USD или BYN и категорию, затем нажмите «Добавить»."
                    )

                    HelpSection(
                        symbol: "chart.pie.fill",
                        title: "Статистика",
                        text: "Внутреннее кольцо показывает категории расходов, внешнее — приближение к месячному лимиту. Стрелки переключают месяцы, а будущие месяцы недоступны."
                    )

                    HelpSection(
                        symbol: "target",
                        title: "Накопления",
                        text: "Создайте цели в настройках и отметьте одну или две. В приложении и Telegram каждая выбранная цель появится отдельным пунктом с названием — сумма пополнит именно её и не войдёт в расходы."
                    )

                    HelpSection(
                        symbol: "clock.arrow.circlepath",
                        title: "История",
                        text: "Значок часов находится сверху. Во вкладке расходов операции можно редактировать и удалять, а во вкладке накоплений — просматривать и удалять ошибочные пополнения."
                    )

                    HelpSection(
                        symbol: "gearshape.fill",
                        title: "Настройки",
                        text: "Нажмите шестерёнку рядом с историей или откройте настройки правым кликом по WhereCash. Там задаются лимит, цели, вторая валюта, автозапуск и новый период статистики без удаления архива и накоплений."
                    )

                    HelpSection(
                        symbol: "banknote.fill",
                        title: "Курс валют",
                        text: "Для пересчёта USD и BYN используется официальный курс НБ РБ. Без сети применяется последний успешно загруженный курс."
                    )

                    HelpSection(
                        symbol: "paperplane.fill",
                        title: "Telegram-бот",
                        text: "Подключите бота в настройках. Кнопка «Добавить» запрашивает сумму, а «Статистика» показывает текущий месяц. Затем валюта и категория выбираются кнопками. Бот работает, пока WhereCash запущен."
                    )
                }
                .padding(18)
            }
        }
        .padding(.vertical)
        .frame(width: 420, height: 680)
    }
}

private struct HelpSection: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.cyan)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
