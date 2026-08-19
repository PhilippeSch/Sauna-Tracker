import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()

guard let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("no ctx") }

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat(r)/255, CGFloat(g)/255, CGFloat(b)/255, a])!
}

let W = CGFloat(size)

// Work in top-left origin coordinates, like the layout was designed.
ctx.translateBy(x: 0, y: W)
ctx.scaleBy(x: 1, y: -1)

// ---------- background ----------
// Clean dark slate rather than a brown haze, so the orange reads as heat.
ctx.saveGState()
let bgColors = [rgb(46, 44, 52), rgb(24, 23, 28), rgb(13, 12, 15)] as CFArray
let bg = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0, 0.55, 1])!
ctx.drawLinearGradient(
    bg,
    start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: W),
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)
ctx.restoreGState()

// ---------- warm glow (behind everything, so nothing gets washed out) ----------
ctx.saveGState()
let glow = CGGradient(
    colorsSpace: cs,
    colors: [rgb(255, 116, 32, 0.50), rgb(255, 110, 30, 0.16), rgb(255, 110, 30, 0)] as CFArray,
    locations: [0, 0.45, 1]
)!
ctx.drawRadialGradient(
    glow,
    startCenter: CGPoint(x: W*0.5, y: W*0.66), startRadius: 0,
    endCenter: CGPoint(x: W*0.5, y: W*0.66), endRadius: W*0.46,
    options: []
)
ctx.restoreGState()

// ---------- heat waves ----------
// Thick snaking strokes with round caps, so the silhouette survives being
// scaled down to a watch home screen.
func wavePath(x: CGFloat, bottom: CGFloat, top: CGFloat, amp: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let h = bottom - top
    p.move(to: CGPoint(x: x, y: bottom))
    p.addCurve(
        to: CGPoint(x: x, y: bottom - h*0.5),
        control1: CGPoint(x: x + amp, y: bottom - h*0.16),
        control2: CGPoint(x: x + amp, y: bottom - h*0.34)
    )
    p.addCurve(
        to: CGPoint(x: x, y: top),
        control1: CGPoint(x: x - amp, y: bottom - h*0.66),
        control2: CGPoint(x: x - amp, y: bottom - h*0.84)
    )
    return p
}

struct Wave { let x: CGFloat; let bottom: CGFloat; let top: CGFloat; let amp: CGFloat; let width: CGFloat; let c0: CGColor; let c1: CGColor }

let waves: [Wave] = [
    Wave(x: W*0.295, bottom: W*0.635, top: W*0.255, amp: W*0.090, width: W*0.062,
         c0: rgb(255, 146, 54), c1: rgb(244, 78, 30)),
    Wave(x: W*0.705, bottom: W*0.635, top: W*0.255, amp: -W*0.090, width: W*0.062,
         c0: rgb(255, 146, 54), c1: rgb(244, 78, 30)),
    Wave(x: W*0.50, bottom: W*0.655, top: W*0.150, amp: W*0.112, width: W*0.082,
         c0: rgb(255, 220, 120), c1: rgb(255, 126, 34)),
]

for w in waves {
    ctx.saveGState()
    ctx.setLineWidth(w.width)
    ctx.setLineCap(.round)
    ctx.addPath(wavePath(x: w.x, bottom: w.bottom, top: w.top, amp: w.amp))
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    let g = CGGradient(colorsSpace: cs, colors: [w.c1, w.c0] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        g,
        start: CGPoint(x: 0, y: w.bottom), end: CGPoint(x: 0, y: w.top),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    ctx.restoreGState()
}

// ---------- sauna stones ----------
// Drawn over the wave roots so the heat reads as rising out of the stones.
struct Stone { let x: CGFloat; let y: CGFloat; let r: CGFloat; let shade: CGFloat }
let stones: [Stone] = [
    Stone(x: W*0.255, y: W*0.700, r: W*0.098, shade: 0.72),
    Stone(x: W*0.745, y: W*0.700, r: W*0.098, shade: 0.72),
    Stone(x: W*0.410, y: W*0.735, r: W*0.115, shade: 1.0),
    Stone(x: W*0.605, y: W*0.730, r: W*0.108, shade: 0.86),
]

for s in stones {
    let top = rgb(Int(126*s.shade), Int(124*s.shade), Int(134*s.shade))
    let bottom = rgb(Int(40*s.shade), Int(39*s.shade), Int(46*s.shade))
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: s.x - s.r, y: s.y - s.r, width: s.r*2, height: s.r*2))
    ctx.clip()
    let g = CGGradient(colorsSpace: cs, colors: [bottom, top] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        g,
        start: CGPoint(x: 0, y: s.y - s.r), end: CGPoint(x: 0, y: s.y + s.r),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    // warm rim on the upper edge — the stones are the thing that is hot
    ctx.setLineWidth(W*0.007)
    ctx.setStrokeColor(rgb(255, 150, 70, 0.32*s.shade))
    ctx.addEllipse(in: CGRect(x: s.x - s.r*0.99, y: s.y - s.r*0.99, width: s.r*1.98, height: s.r*1.98))
    ctx.strokePath()
    ctx.restoreGState()
}

// ---------- heater base ----------
let baseRect = CGRect(x: W*0.215, y: W*0.800, width: W*0.57, height: W*0.062)
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: baseRect, cornerWidth: W*0.022, cornerHeight: W*0.022, transform: nil))
ctx.clip()
let baseG = CGGradient(colorsSpace: cs, colors: [rgb(30, 29, 35), rgb(72, 70, 80)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(
    baseG,
    start: CGPoint(x: 0, y: baseRect.minY), end: CGPoint(x: 0, y: baseRect.maxY),
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)
ctx.restoreGState()

guard let image = ctx.makeImage() else { fatalError("no image") }
let out = URL(fileURLWithPath: CommandLine.arguments[1])
guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("no dest")
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(out.path)")
