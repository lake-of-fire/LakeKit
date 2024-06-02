//
//  MarqueeView.swift
//  MarqueeSwiftUI
//
//  Created by Naina Maharjan on 28/02/2024.
//

import SwiftUI

public struct Marquee<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var containerWidth: CGFloat? = nil
    @State private var model: MarqueeModel
    private var isActive: Bool
    private var targetVelocity: Double
    private var spacing: CGFloat
    
    public init(isActive: Bool, targetVelocity: Double, spacing: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.isActive = isActive
        self.content = content()
        self._model = .init(wrappedValue: MarqueeModel(targetVelocity: targetVelocity, spacing: spacing))
        self.targetVelocity = targetVelocity
        self.spacing = spacing
    }
    
    var extraContentInstances: Int {
        let contentPlusSpacing = ((model.contentWidth ?? 0) + model.spacing)
        guard contentPlusSpacing != 0 else { return 1 }
        return Int(((containerWidth ?? 0) / contentPlusSpacing).rounded(.up))
    }
    
    public var body: some View {
        TimelineView(.animation(minimumInterval: 0.01 * targetVelocity, paused: !model.isAnimating || !isActive)) { context in
            HStack(spacing: model.spacing) {
                HStack(spacing: model.spacing) {
                    content
                }
                .measureWidth { model.contentWidth = $0 }
                ForEach(Array(0..<extraContentInstances), id: \.self) { _ in
                    content
                }
            }
            .offset(x: model.offset)
            .fixedSize()
            .onChange(of: context.date) { newDate in
                model.tick(at: newDate)
            }
        }
        .measureWidth { containerWidth = $0 }
        .gesture(dragGesture)
        .onAppear { model.previousTick = .now }
        .onAppear { model.isAnimating = isActive }
        .onDisappear { model.isAnimating = false }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .onChange(of: isActive) { newValue in
            if !newValue {
                model.reset()
            }
            model.isAnimating = newValue
        }
    }
    
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                model.dragChanged(value)
            }.onEnded { value in
                model.dragEnded(value)
            }
    }
}

struct MarqueeModel {
    var contentWidth: CGFloat? = nil
    var offset: CGFloat = 0
    var dragStartOffset: CGFloat? = nil
    var dragTranslation: CGFloat = 0
    var currentVelocity: CGFloat = 0
    var isAnimating: Bool = true
    
    var previousTick: Date = .now
    var targetVelocity: Double
    var spacing: CGFloat
    
    init(targetVelocity: Double, spacing: CGFloat) {
        self.targetVelocity = targetVelocity
        self.spacing = spacing
    }
    
    mutating func tick(at time: Date) {
        guard isAnimating else { return }
        
        let delta = time.timeIntervalSince(previousTick)
        defer { previousTick = time }
        currentVelocity += (targetVelocity - currentVelocity) * delta * 3
        if let dragStartOffset {
            offset = dragStartOffset + dragTranslation
        } else {
            offset -= delta * currentVelocity
        }
        if let c = contentWidth {
            offset.formTruncatingRemainder(dividingBy: c + spacing)
            while offset > 0 {
                offset -= c + spacing
            }
        }
    }
    
    mutating func dragChanged(_ value: DragGesture.Value) {
        if dragStartOffset == nil {
            dragStartOffset = offset
        }
        dragTranslation = value.translation.width
    }
    
    mutating func dragEnded(_ value: DragGesture.Value) {
        offset = dragStartOffset! + value.translation.width
        dragStartOffset = nil
    }
    
    mutating func reset() {
        offset = 0
        currentVelocity = 0
        previousTick = .now
        dragStartOffset = nil
        dragTranslation = 0
    }
}

extension View {
    func measureWidth(_ onChange: @escaping (CGFloat) -> ()) -> some View {
        background {
            GeometryReader { proxy in
                let width = proxy.size.width
                Color.clear
                    .onAppear {
                        DispatchQueue.main.async {
                            onChange(width)
                        }
                    }.onChange(of: width) {
                        onChange($0)
                    }
            }
        }
    }
}
