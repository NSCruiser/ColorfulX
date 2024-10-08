//
//  ColorfulView.swift
//
//
//  Created by QAQ on 2023/12/3.
//

import ColorVector
import SwiftUI

public struct ColorfulView: View {
    @Binding var color: [Color]
    @Binding var speed: Double
    @Binding var bias: Double
    @Binding var noise: Double
    @Binding var transitionSpeed: Double
    @Binding var frameLimit: Int
    @Binding var renderScale: Double
    @Binding var pauseRender: Bool

    let repeats: Bool

    public init(
        color: Binding<[Color]>,
        speed: Binding<Double> = .constant(1.0),
        bias: Binding<Double> = .constant(0.01),
        noise: Binding<Double> = .constant(0),
        transitionSpeed: Binding<Double> = .constant(5),
        frameLimit: Binding<Int> = .constant(0),
        renderScale: Binding<Double> = .constant(1.0),
        pauseRender: Binding<Bool> = .constant(false),
        repeats: Bool = true
    ) {
        _color = color
        _speed = speed
        _bias = bias
        _noise = noise
        _transitionSpeed = transitionSpeed
        _frameLimit = frameLimit
        _renderScale = renderScale
        _pauseRender = pauseRender

        self.repeats = repeats
    }

    public var body: some View {
        AnimatedMulticolorGradientViewRepresentable(
            color: .init(get: {
                color.map { ColorVector(ColorElement($0)) }
            }, set: { _ in }),
            speed: $speed,
            bias: $bias,
            noise: $noise,
            transitionSpeed: $transitionSpeed,
            frameLimit: $frameLimit,
            renderScale: $renderScale,
            pauseRender: $pauseRender,
            repeats: repeats
        )
    }
}
