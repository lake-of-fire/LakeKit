// From: https://github.com/nainamaharjan/MarqueeSwiftUI
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
    private var horizontalInset: CGFloat
    private var targetVelocity: Double
    private var spacing: CGFloat
    
    public init(horizontalInset: CGFloat = 0, targetVelocity: Double, spacing: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.horizontalInset = horizontalInset
        self.content = content()
        self._model = .init(wrappedValue: MarqueeModel(horizontalInset: horizontalInset, targetVelocity: targetVelocity, spacing: spacing))
        self.targetVelocity = targetVelocity
        self.spacing = spacing
    }
    
    var extraContentInstances: Int {
        let contentPlusSpacing = ((model.contentWidth ?? 0) + model.spacing)
        guard contentPlusSpacing != 0 else { return 1 }
        return Int(((containerWidth ?? 0) / contentPlusSpacing).rounded(.up)) + 1
    }
    
    public var body: some View {
        TimelineView(.animation) { context in
            HStack(spacing: model.spacing) {
                HStack(spacing: model.spacing) {
                    content
                }
                .measureWidth {
                    model.contentWidth = $0
                    model.horizontalInset = horizontalInset
                }
                ForEach(Array(0..<extraContentInstances), id: \.self) { _ in
                    content
                }
            }
            .offset(x: model.offset)
            .fixedSize()
            .onChange(of: context.date) { newDate in
                DispatchQueue.main.async {
                    model.tick(at: newDate)
                    
                }
            }
        }
        .measureWidth { containerWidth = $0 }
        .gesture(dragGesture)
        .onAppear { model.previousTick = .now }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
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
    var horizontalInset: CGFloat = 0
    var offset: CGFloat = 0
    var dragStartOffset: CGFloat? = nil
    var dragTranslation: CGFloat = 0
    var currentVelocity: CGFloat = 0
    
    var previousTick: Date = .now
    var targetVelocity: Double
    var spacing: CGFloat
    init(horizontalInset: CGFloat, targetVelocity: Double, spacing: CGFloat) {
        self.horizontalInset = horizontalInset
        self.targetVelocity = targetVelocity
        self.spacing = spacing
    }
    
    mutating func tick(at time: Date) {
        let delta = time.timeIntervalSince(previousTick)
        defer { previousTick = time }
        currentVelocity += (targetVelocity - currentVelocity) * delta * 3
        if let dragStartOffset {
            offset = dragStartOffset + dragTranslation
        } else {
            offset -= delta * currentVelocity
        }
        if let cWidth = contentWidth {
            let c = cWidth
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
