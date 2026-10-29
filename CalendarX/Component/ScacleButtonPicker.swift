//
//  ScacleButtonPicker.swift
//  CalendarX
//
//  Created by zm on 2022/1/28.
//
import AppKit
import CalendarXLib
import SwiftUI

struct ScacleButtonPicker<Item: Hashable, Label: View, ItemLabel: View>: View {


    private let items: [Item]

    @Binding
    private var selection: Item

    @Binding
    private var isPresented: Bool

    private let label: () -> Label, itemLabel: (Item) -> ItemLabel

    private let tint: Color, width: CGFloat, arrowEdge: Edge


    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.locale)
    private var locale

    init(
        items: [Item],
        tint: Color,
        width: CGFloat = .popoverWidth,
        arrowEdge: Edge = .bottom,
        selection: Binding<Item>,
        isPresented: Binding<Bool>,
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder itemLabel: @escaping (Item) -> ItemLabel
    ) {
        self.items = items
        self.tint = tint
        self.width = width
        self.arrowEdge = arrowEdge
        self._selection = selection
        self._isPresented = isPresented
        self.label = label
        self.itemLabel = itemLabel
    }

    var body: some View {
        ScacleButton {
            DispatchQueue.main.async {
                isPresented.toggle()
            }
        } label: {
            label()
        }
        .popover(isPresented: $isPresented, attachmentAnchor: .rect(.bounds), arrowEdge: arrowEdge) {
            popoverContent()
                .preferredLocale(locale)
                .preferredColorScheme(colorScheme)
        }
    }

    @ViewBuilder
    func popoverContent() -> some View {
        ScrollViewReader { reader in
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.fixed(width))], spacing: 0) {
                    ForEach(items, id: \.self) { item in
                        Button {
                            selection = item
                            isPresented.toggle()
                        } label: {
                            itemLabel(item)
                                .appForeground(item == selection ? tint : .primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .id(item)
                        .buttonStyle(.plain)
                        .frame(height: .popoverRowHeight)
                    }
                }
                .padding(5)
            }
            .frame(height: min(CGFloat(items.count) * .popoverRowHeight + 10, .popoverHeight))
            .onAppear { reader.scrollTo(selection) }
        }
    }
}

struct AppMenuButton: NSViewRepresentable {
    var titles: [String]
    var selection: Int
    var tint: Color
    var textStyle: NSFont.TextStyle = .title2
    var onSelect: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeNSView(context: Context) -> AppMenuControl {
        let control = AppMenuControl()
        control.onSelect = { context.coordinator.onSelect($0) }
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .vertical)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .vertical)
        return control
    }

    func updateNSView(_ control: AppMenuControl, context: Context) {
        context.coordinator.onSelect = onSelect
        guard !control.isMenuOpen else { return }
        control.titles = titles
        control.selection = selection
        control.textFont = .preferredFont(forTextStyle: textStyle)
        if #available(macOS 14.0, *) {
            control.titleColor = NSColor(tint)
        } else {
            control.titleColor = .labelColor
        }
        control.invalidateIntrinsicContentSize()
        control.needsDisplay = true
    }

    final class Coordinator {
        var onSelect: (Int) -> Void
        init(onSelect: @escaping (Int) -> Void) {
            self.onSelect = onSelect
        }
    }
}

final class AppMenuControl: NSView {
    var titles: [String] = []
    var selection = 0
    var titleColor: NSColor = .labelColor
    var textFont: NSFont = .preferredFont(forTextStyle: .title2)
    var onSelect: ((Int) -> Void)?
    private(set) var isMenuOpen = false

    override var intrinsicContentSize: NSSize {
        let title = currentTitle as NSString
        let width = title.size(withAttributes: [.font: textFont]).width
        return NSSize(width: ceil(width) + 18, height: 30)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.showMenu()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let text = currentTitle as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: titleColor
        ]
        let size = text.size(withAttributes: attributes)
        let rect = NSRect(
            x: 0,
            y: (bounds.height - size.height) / 2,
            width: min(size.width, bounds.width),
            height: size.height
        )
        text.draw(in: rect, withAttributes: attributes)
    }

    private func showMenu() {
        guard !titles.isEmpty, window != nil, !isMenuOpen else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false
        for (index, title) in titles.enumerated() {
            let item = NSMenuItem(title: title, action: #selector(pick(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = index == selection ? .on : .off
            menu.addItem(item)
        }
        isMenuOpen = true
        menu.popUp(positioning: menu.item(withTag: selection), at: NSPoint(x: 0, y: bounds.height), in: self)
        isMenuOpen = false
    }

    @objc private func pick(_ sender: NSMenuItem) {
        onSelect?(sender.tag)
    }

    private var currentTitle: String {
        titles.indices.contains(selection) ? titles[selection] : ""
    }
}
