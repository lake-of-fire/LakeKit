//
//  WheelScroll.swift
//  TestSwiftUI
//
//  Created by Илья Аникин on 19.10.2023.

import SwiftUI

@available(iOS 17, macOS 14, *)
public struct WheelScroll<Content: View>: View {
    let axis: Axis.Set
    let contentSpacing: CGFloat
    
    @ViewBuilder let content: () -> Content

    public init(axis: Axis.Set = .vertical, contentSpacing: CGFloat = 15, content: @escaping () -> Content) {
        self.axis = axis
        self.contentSpacing = contentSpacing
        self.content = content
    }
    
    private var timingCurve: UnitCurve { axis.isVertical ? .easeIn : .easeOut }
    private var opacityThreshold: ScrollTransitionConfiguration.Threshold {
        axis.isVertical ? .visible(0.4) : .visible
    }
    private var blurThreshold: ScrollTransitionConfiguration.Threshold {
        axis.isVertical ? .visible(0.6) : .visible(0.8)
    }
    
    public var body: some View {
        ScrollView(axis, showsIndicators: true) {
            VStack(spacing: 0) {
                content()
                    .scrollTransition(
                        .interactive(timingCurve: .easeIn),
                        transition: scrollTransitionRoll
                    )
                    .scrollTransition(
                        .interactive(timingCurve: timingCurve).threshold(blurThreshold)
                    ) { effect, phase in
                        effect
                            .blur(radius: phase.isIdentity ? 0 : 2.2)
                            .scaleEffect(
                                x: phase.isIdentity
                                ? 1
                                : axis.isVertical ? 0.875 : 1,
                                y: phase.isIdentity
                                ? 1
                                : axis == .horizontal ? 0.925 : 1
                            )
                    }
                    .scrollTransition(
                        .interactive(timingCurve: timingCurve).threshold(opacityThreshold)
                    ) { effect, phase in
                        effect.opacity(phase.isIdentity ? 1 : 0.333)
                    }
                    .embedInStack(axis, spacing: contentSpacing)
                    .scrollTargetLayout()
                
                Text("") // scrollTargetLayout bug workaround
                    .frame(width: 0, height: 0)
            }
        }
//        .scrollClipDisabled()
        .frame(maxWidth: .infinity)
        .defaultScrollAnchor(.topLeading) // used by scrollTransitionRoll
//        .padding(20)
//        .clipShape(.rect)
    }
    
    @Sendable
    func scrollTransitionRoll(effect: EmptyVisualEffect, phase: ScrollTransitionPhase) -> some VisualEffect {
        effect
            .rotation3DEffect(
                .degrees(phase.isIdentity ? 0 : 40),
                axis: axis.isVertical ? (x: 1, y: 0, z: 0) : (x: 0, y: 1, z: 0),
                anchor: {
                    switch phase {
                    case .topLeading:
                        axis.isVertical ? .bottom : .trailing
                    case .identity:
                            .center
                    case .bottomTrailing:
                        axis.isVertical ? .top : .leading
                    }
                }(),
                anchorZ: 0,
                perspective: {
                    switch phase {
                    case .topLeading:
                        axis.isVertical ? 0.3 : -0.3
                    case .identity:
                        0
                    case .bottomTrailing:
                        axis.isVertical ? -0.3 : 0.3
                    }
                }()
            )
    }
}

fileprivate extension Axis.Set {
    var isVertical: Bool {
        self == .vertical
    }
}

fileprivate extension View {
    @ViewBuilder
    func embedInStack(_ axis: Axis.Set, spacing: CGFloat) -> some View {
        switch axis {
        case .horizontal:
            LazyHStack(spacing: spacing, content: { self })
        default:
            LazyVStack(spacing: spacing, content: { self })
        }
    }
}
//
//extension Image {
//    static func whiteToClearGradient(size: CGSize) -> Image {
//        let renderer = UIGraphicsImageRenderer(size: size)
//        let image = renderer.image { context in
//            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
//                                      colors: [UIColor.white.cgColor, UIColor.clear.cgColor] as CFArray,
//                                      locations: [0, 1])!
//            let startPoint = CGPoint(x: size.width / 2, y: 0)
//            let endPoint = CGPoint(x: size.width / 2, y: size.height)
//            context.cgContext.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
//        }
//        return Image(uiImage: image)
//    }
//}
