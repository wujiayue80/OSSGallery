import SwiftUI

/// 绚丽的原生烟花粒子特效。
///
/// 在“随机探索”轮播停止定格时触发：
/// 多点绽放、高亮霓虹色系粒子、重力加速度下坠与自然渐隐，由硬件加速的 Canvas 渲染。
struct FireworksView: View {
    let onFinished: () -> Void

    @State private var startTime: Date = Date()
    @State private var bursts: [FireworkBurst] = []
    @State private var opacity: Double = 1.0

    private let burstColors: [[Color]] = [
        [.cyan, .blue, .white, .mint],
        [.pink, .purple, .yellow, .white],
        [.yellow, .orange, .pink, .white],
        [.green, .mint, .cyan, .yellow]
    ]

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSince(startTime)
                    guard elapsed < 2.0 else { return }

                    for burst in bursts {
                        let burstElapsed = elapsed - burst.delay
                        guard burstElapsed > 0 else { continue }

                        for p in burst.particles {
                            let t = burstElapsed
                            let progress = min(1.0, t / p.duration)
                            guard progress < 1.0 else { continue }

                            // 物理运动公式：位移 + 重力下坠
                            let curX = burst.origin.x + p.vx * t
                            let curY = burst.origin.y + p.vy * t + 140 * t * t
                            let alpha = max(0, 1.0 - progress) * p.initialAlpha

                            let curSize = p.size * (1.0 - progress * 0.4)
                            let rect = CGRect(x: curX - curSize / 2, y: curY - curSize / 2, width: curSize, height: curSize)

                            context.opacity = alpha * opacity
                            context.fill(Path(ellipseIn: rect), with: .color(p.color))
                        }
                    }
                }
            }
            .onAppear {
                spawnBursts(in: proxy.size)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func spawnBursts(in size: CGSize) {
        startTime = Date()
        let centers = [
            (CGPoint(x: size.width * 0.32, y: size.height * 0.38), 0.0),
            (CGPoint(x: size.width * 0.68, y: size.height * 0.36), 0.08),
            (CGPoint(x: size.width * 0.50, y: size.height * 0.28), 0.16),
            (CGPoint(x: size.width * 0.50, y: size.height * 0.55), 0.24)
        ]

        var generated: [FireworkBurst] = []
        for (index, item) in centers.enumerated() {
            let (point, delay) = item
            let palette = burstColors[index % burstColors.count]
            var particles: [Particle] = []

            for _ in 0..<45 {
                let angle = Double.random(in: 0...(2 * .pi))
                let speed = Double.random(in: 90...260)
                let vx = cos(angle) * speed
                let vy = sin(angle) * speed
                let color = palette.randomElement() ?? .cyan
                let duration = Double.random(in: 1.2...1.8)
                let particleSize = CGFloat.random(in: 3.5...7.0)

                particles.append(
                    Particle(
                        vx: vx,
                        vy: vy,
                        color: color,
                        size: particleSize,
                        duration: duration,
                        initialAlpha: Double.random(in: 0.85...1.0)
                    )
                )
            }

            generated.append(FireworkBurst(origin: point, delay: delay, particles: particles))
        }

        self.bursts = generated

        // 2秒后淡出并回调完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onFinished()
            }
        }
    }

    private struct FireworkBurst {
        let origin: CGPoint
        let delay: TimeInterval
        let particles: [Particle]
    }

    private struct Particle {
        let vx: Double
        let vy: Double
        let color: Color
        let size: CGFloat
        let duration: Double
        let initialAlpha: Double
    }
}
