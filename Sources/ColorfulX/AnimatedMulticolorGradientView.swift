//
//  AnimatedMulticolorGradientView.swift
//
//
//  Created by QAQ on 2023/12/3.
//

import MetalKit
import SpringInterpolation

private let COLOR_SLOT = 8
private let SPRING_CONFIG = SpringInterpolation.Configuration(
    angularFrequency: 1.5,
    dampingRatio: 0.2
)
private let SPRING_ENGINE = SpringInterpolation2D(SPRING_CONFIG)

open class AnimatedMulticolorGradientView: MulticolorGradientView {
    public var lastUpdate: Double = 0
    public var lastRender: Double = 0
    public private(set) var colorElements: [Speckle]

    public var speed: Double = 1.0
    public var bias: Double = 0.01
    public var noise: Double = 0
    public var transitionDuration: TimeInterval = 5
    public var frameLimit: Int = 0

    override public init(interpolationOption: InterpolationOption = .lab) {
        colorElements = .init(repeating: .init(position: SPRING_ENGINE), count: COLOR_SLOT)

        super.init(interpolationOption: interpolationOption)

        var rand = randomLocationPair()
        for idx in 0 ..< colorElements.count {
            rand = randomLocationPair()
            colorElements[idx].position.setCurrent(.init(x: rand.x, y: rand.y))
            rand = randomLocationPair()
            colorElements[idx].position.setTarget(.init(x: rand.x, y: rand.y))
        }

        #if canImport(UIKit)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(applicationWillEnterForeground(_:)),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
        #endif
    }

    @objc
    func applicationWillEnterForeground(_: Notification) {
        lastRender = .init()
    }

    deinit {
        #if canImport(UIKit)
            NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        #endif
    }

    private func randomLocationPair() -> (x: Double, y: Double) {
        (
            x: Double.random(in: 0 ... 1),
            y: Double.random(in: 0 ... 1)
        )
    }

    public func setColors(_ colors: [RGBColor], interpolationEnabled: Bool = true) {
        for idx in 0 ..< COLOR_SLOT {
            var read = colorElements[idx]
            let color: RGBColor = colors.isEmpty
                ? RGBColor(r: 0.5, g: 0.5, b: 0.5)
                : colors[idx % colors.count]
            guard read.targetColor != color else { continue }
            let interpolationEnabled = interpolationEnabled && read.enabled
            let currentColor = computeSpeckleColor(read)
            read.enabled = true
            read.targetColor = color
            read.previousColor = interpolationEnabled ? currentColor : color
            read.transitionProgress = interpolationEnabled ? 0 : 1
            colorElements[idx] = read
        }
    }

    private func updateRenderParameters() {
        var deltaTime = -Date(timeIntervalSince1970: lastUpdate).timeIntervalSinceNow
        lastUpdate = Date().timeIntervalSince1970
        guard deltaTime > 0 else { return }

        // when the app goes back from background, deltaTime could be very large
        let maxDeltaAllowed = 1.0 / Double(frameLimit > 0 ? frameLimit : 30)
        deltaTime = min(deltaTime, maxDeltaAllowed)

        let moveDelta = deltaTime * speed * 0.5 // just slow down

        for idx in 0 ..< colorElements.count where colorElements[idx].enabled {
            var inplaceEdit = colorElements[idx]
            defer { colorElements[idx] = inplaceEdit }

            if inplaceEdit.transitionProgress < 1 {
                inplaceEdit.transitionProgress += deltaTime / transitionDuration
            }
            if moveDelta > 0 {
                inplaceEdit.position.update(withDeltaTime: moveDelta)

                let pos_x = inplaceEdit.position.x.context.currentPos
                let tar_x = inplaceEdit.position.x.context.targetPos
                let pos_y = inplaceEdit.position.y.context.currentPos
                let tar_y = inplaceEdit.position.y.context.targetPos
                if abs(pos_x - tar_x) < 0.125 || abs(pos_y - tar_y) < 0.125 {
                    let rand = randomLocationPair()
                    inplaceEdit.position.setTarget(.init(x: rand.x, y: rand.y))
                }
            }
        }

        parameters = .init(
            points: colorElements
                .filter(\.enabled)
                .map { .init(
                    color: computeSpeckleColor($0),
                    position: .init(
                        x: $0.position.x.context.currentPos,
                        y: $0.position.y.context.currentPos
                    )
                ) },
            bias: Float(bias),
            noise: Float(noise)
        )
    }

    override public func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        updateRenderParameters()
        super.vsync()
    }

    override func vsync() {
        // when calling from vsync, MetalView is holding strong reference.
        DispatchQueue.main.asyncAndWait(execute: DispatchWorkItem {
            if self.frameLimit > 0 {
                let now = Date().timeIntervalSince1970
                guard now - self.lastRender > 1.0 / Double(self.frameLimit) else { return }
                self.lastRender = now
            }
            self.updateRenderParameters()
        })
        super.vsync()
    }

    func computeSpeckleColor(_ speckle: Speckle) -> RGBColor {
        switch interpolationOption {
        case .rgb: return speckle.previousColor.lerpWithRGB(to: speckle.targetColor, percent: speckle.transitionProgress)
        case .xyz: return speckle.previousColor.lerpWithXYZ(to: speckle.targetColor, percent: speckle.transitionProgress)
        case .lab: return speckle.previousColor.lerpWithLAB(to: speckle.targetColor, percent: speckle.transitionProgress)
        case .lch: return speckle.previousColor.lerpWithLCH(to: speckle.targetColor, percent: speckle.transitionProgress)
        }
    }
}
