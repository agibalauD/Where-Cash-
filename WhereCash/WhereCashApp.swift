import AppKit
import SwiftData
import SwiftUI

@main
struct WhereCashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let modelContainer = try ModelContainer(
                for: ExpenseRecord.self,
                SavingsGoal.self,
                SavingsContribution.self
            )
            let exchangeRateService = ExchangeRateService()
            let telegramBotService = TelegramBotService(
                modelContainer: modelContainer,
                exchangeRateService: exchangeRateService
            )
            let router = PanelRouter()

            statusBarController = StatusBarController(
                modelContainer: modelContainer,
                exchangeRateService: exchangeRateService,
                telegramBotService: telegramBotService,
                router: router
            )
            telegramBotService.start()
        } catch {
            fatalError("Не удалось открыть локальную базу: \(error.localizedDescription)")
        }
    }
}

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let router: PanelRouter
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    init(
        modelContainer: ModelContainer,
        exchangeRateService: ExchangeRateService,
        telegramBotService: TelegramBotService,
        router: PanelRouter
    ) {
        self.router = router
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()

        super.init()

        let rootView = MenuBarContentView(router: router)
            .modelContainer(modelContainer)
            .environmentObject(exchangeRateService)
            .environmentObject(telegramBotService)

        popover.contentSize = NSSize(width: 420, height: 680)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: rootView)

        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "banknote.fill", accessibilityDescription: "WhereCash")
        button.image?.isTemplate = true
        button.toolTip = "WhereCash"
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover(relativeTo: sender)
            return
        }

        let isContextClick = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        if isContextClick {
            popover.performClose(nil)
            showContextMenu()
        } else {
            togglePopover(relativeTo: sender)
        }
    }

    private func togglePopover(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(relativeTo: button)
        }
    }

    private func showPopover(relativeTo button: NSStatusBarButton) {
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        startOutsideClickMonitoring()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func startOutsideClickMonitoring() {
        stopOutsideClickMonitoring()

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            guard let self else { return event }

            if self.isEventInsidePopover(event) || self.isEventInsideStatusButton(event) {
                return event
            }

            self.popover.performClose(nil)
            return event
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.popover.performClose(nil)
            }
        }
    }

    private func stopOutsideClickMonitoring() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }

        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    private func isEventInsidePopover(_ event: NSEvent) -> Bool {
        event.window === popover.contentViewController?.view.window
    }

    private func isEventInsideStatusButton(_ event: NSEvent) -> Bool {
        guard
            let button = statusItem.button,
            let buttonWindow = button.window,
            event.window === buttonWindow
        else {
            return false
        }

        let pointInButton = button.convert(event.locationInWindow, from: nil)
        return button.bounds.contains(pointInButton)
    }

    func popoverDidClose(_ notification: Notification) {
        stopOutsideClickMonitoring()
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "Настройки",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let helpItem = NSMenuItem(
            title: "Помощь",
            action: #selector(openHelp),
            keyEquivalent: "?"
        )
        helpItem.target = self
        menu.addItem(helpItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Выйти",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        openPanel(.settings)
    }

    @objc private func openHelp() {
        openPanel(.help)
    }

    private func openPanel(_ section: PanelSection) {
        router.show(section)
        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.statusItem.button else { return }
            self.showPopover(relativeTo: button)
        }
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
}
