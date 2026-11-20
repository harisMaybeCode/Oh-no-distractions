// Renders the Site Blocker artwork.
// usage: swift render.swift icon <out.png>        -> 1024x1024 macOS app icon
//        swift render.swift background <out.png>  -> full-bleed window background
import AppKit

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let space = CGColorSpaceCreateDeviceRGB()

func gradientFill(_ ctx: CGContext, _ rect: CGRect) {
    let g = CGGradient(colorsSpace: space,
                       colors: [color(0x2B1E6B), color(0x5B3BE8), color(0xE8436B), color(0xFF8A3D)] as CFArray,
                       locations: [0, 0.38, 0.78, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: rect.minX, y: rect.maxY),
                           end: CGPoint(x: rect.maxX, y: rect.minY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    // soft glows
    for (c, x, y, r) in [(color(0xFFFFFF, 0.22), 0.25, 0.80, 0.55), (color(0xFFB36B, 0.30), 0.85, 0.15, 0.50)] {
        let glow = CGGradient(colorsSpace: space, colors: [c, color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
        let center = CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center,
                               endRadius: max(rect.width, rect.height) * r, options: [])
    }
}

/// The emblem: a browser window with a clock inside, crossed by a "blocked" slash.
/// Drawn centered at `c` with overall width `w`.
func emblem(_ ctx: CGContext, center c: CGPoint, width w: CGFloat) {
    let h = w * 0.78
    let win = CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
    let lw = w * 0.055
    let white = color(0xFFFFFF)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -w * 0.03), blur: w * 0.08, color: color(0x140A3A, 0.45))

    // frosted window body
    let body = CGPath(roundedRect: win, cornerWidth: w * 0.12, cornerHeight: w * 0.12, transform: nil)
    ctx.addPath(body); ctx.setFillColor(color(0xFFFFFF, 0.16)); ctx.fillPath()
    ctx.addPath(body); ctx.setStrokeColor(white); ctx.setLineWidth(lw); ctx.strokePath()
    ctx.restoreGState()

    // title bar line + three dots
    let barY = win.maxY - h * 0.20
    ctx.setStrokeColor(white); ctx.setLineWidth(lw * 0.7); ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: win.minX + lw / 2, y: barY)); ctx.addLine(to: CGPoint(x: win.maxX - lw / 2, y: barY)); ctx.strokePath()
    let dotR = w * 0.03
    for i in 0..<3 {
        let dc = CGPoint(x: win.minX + w * 0.12 + CGFloat(i) * w * 0.095, y: (barY + win.maxY) / 2)
        ctx.setFillColor(white)
        ctx.fillEllipse(in: CGRect(x: dc.x - dotR, y: dc.y - dotR, width: dotR * 2, height: dotR * 2))
    }

    // clock, hands at 10:10
    let cc = CGPoint(x: c.x - w * 0.06, y: (win.minY + barY) / 2)
    let cr = (barY - win.minY) * 0.33
    ctx.setStrokeColor(white); ctx.setLineCap(.round)
    ctx.setLineWidth(lw * 0.8)
    ctx.strokeEllipse(in: CGRect(x: cc.x - cr, y: cc.y - cr, width: cr * 2, height: cr * 2))
    ctx.setLineWidth(lw * 0.75)
    ctx.move(to: cc); ctx.addLine(to: CGPoint(x: cc.x + cr * 0.50, y: cc.y + cr * 0.40)); ctx.strokePath()
    ctx.move(to: cc); ctx.addLine(to: CGPoint(x: cc.x - cr * 0.38, y: cc.y + cr * 0.22)); ctx.strokePath()
    ctx.setFillColor(white)
    ctx.fillEllipse(in: CGRect(x: cc.x - lw * 0.6, y: cc.y - lw * 0.6, width: lw * 1.2, height: lw * 1.2))

    // "blocked" badge in the bottom-right corner
    let bc = CGPoint(x: win.maxX - w * 0.04, y: win.minY + w * 0.04)
    let br = w * 0.25
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -w * 0.02), blur: w * 0.05, color: color(0x3A0A1A, 0.5))
    ctx.setFillColor(white)
    ctx.fillEllipse(in: CGRect(x: bc.x - br, y: bc.y - br, width: br * 2, height: br * 2))
    ctx.restoreGState()
    let ir = br * 0.80
    let red = CGGradient(colorsSpace: space, colors: [color(0xFF5A6E), color(0xE5213F)] as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: bc.x - ir, y: bc.y - ir, width: ir * 2, height: ir * 2)); ctx.clip()
    ctx.drawLinearGradient(red, start: CGPoint(x: bc.x, y: bc.y + ir), end: CGPoint(x: bc.x, y: bc.y - ir), options: [])
    ctx.restoreGState()
    let sr = ir * 0.58
    ctx.setStrokeColor(white); ctx.setLineWidth(br * 0.16); ctx.setLineCap(.round)
    ctx.strokeEllipse(in: CGRect(x: bc.x - sr, y: bc.y - sr, width: sr * 2, height: sr * 2))
    let d = sr * 0.7071
    ctx.move(to: CGPoint(x: bc.x - d, y: bc.y + d)); ctx.addLine(to: CGPoint(x: bc.x + d, y: bc.y - d)); ctx.strokePath()
}


func grassScene(_ ctx: CGContext, _ r: CGRect) {
    // sky
    let sky = CGGradient(colorsSpace: space, colors: [color(0x4FB3FF), color(0xA8E2FF)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sky, start: CGPoint(x: r.midX, y: r.maxY), end: CGPoint(x: r.midX, y: r.minY), options: [])
    // sun
    let sc = CGPoint(x: r.minX + r.width * 0.80, y: r.minY + r.height * 0.80)
    let glow = CGGradient(colorsSpace: space, colors: [color(0xFFF6B0, 0.9), color(0xFFF6B0, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: sc, startRadius: 0, endCenter: sc, endRadius: r.width * 0.30, options: [])
    ctx.setFillColor(color(0xFFD93D))
    let sr = r.width * 0.09
    ctx.fillEllipse(in: CGRect(x: sc.x - sr, y: sc.y - sr, width: sr * 2, height: sr * 2))
}

func blades(_ ctx: CGContext, _ r: CGRect, baseY: CGFloat, height: CGFloat, count: Int, seed: UInt64, dark: Bool) {
    var rng = seed
    func rand() -> CGFloat { rng = rng &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(rng >> 33) / CGFloat(1 << 31) }
    let g = CGGradient(colorsSpace: space,
                       colors: (dark ? [color(0x1E8A3A), color(0x4CC04F)] : [color(0x2FA84A), color(0x8BE05A)]) as CFArray,
                       locations: [0, 1])!
    let step = r.width / CGFloat(count)
    for i in 0..<count {
        let x = r.minX + (CGFloat(i) + rand() * 0.6) * step
        let w = step * (1.3 + rand() * 0.8)
        let h = height * (0.65 + rand() * 0.5)
        let lean = (rand() - 0.5) * w * 1.6
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x - w / 2, y: r.minY))
        path.addLine(to: CGPoint(x: x - w / 2, y: baseY))
        path.addQuadCurve(to: CGPoint(x: x + lean, y: baseY + h), control: CGPoint(x: x - w * 0.3, y: baseY + h * 0.6))
        path.addQuadCurve(to: CGPoint(x: x + w / 2, y: baseY), control: CGPoint(x: x + w * 0.3, y: baseY + h * 0.5))
        path.addLine(to: CGPoint(x: x + w / 2, y: r.minY))
        path.closeSubpath()
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        ctx.drawLinearGradient(g, start: CGPoint(x: x, y: baseY - height * 0.3), end: CGPoint(x: x, y: baseY + h), options: [.drawsBeforeStartLocation])
        ctx.restoreGState()
    }
}

func render(size: CGSize, _ draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    draw(ctx)
    return rep
}

let args = CommandLine.arguments
let mode = args[1], out = args[2]
var rep: NSBitmapImageRep

if mode == "panel" {
    let img = NSImage(contentsOfFile: args[3])!
    let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    rep = render(size: CGSize(width: 1024, height: 1024)) { ctx in
        let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
        let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
        ctx.addPath(shape); ctx.setFillColor(color(0xFFFFFF)); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(shape); ctx.clip()
        ctx.interpolationQuality = .high
        // aspect-fill the panel into the tile
        let iw = CGFloat(cg.width), ih = CGFloat(cg.height)
        let scale = max(tile.width / iw, tile.height / ih)
        let dw = iw * scale, dh = ih * scale
        ctx.draw(cg, in: CGRect(x: tile.midX - dw / 2, y: tile.midY - dh / 2, width: dw, height: dh))
        ctx.restoreGState()
        // thin edge so the white icon doesn't vanish on light backgrounds
        ctx.addPath(shape); ctx.setStrokeColor(color(0x000000, 0.18)); ctx.setLineWidth(4); ctx.strokePath()
    }
} else if mode == "grass" {
    rep = render(size: CGSize(width: 1024, height: 1024)) { ctx in
        let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
        let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
        ctx.addPath(shape); ctx.setFillColor(color(0x000000)); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(shape); ctx.clip()
        grassScene(ctx, tile)
        blades(ctx, tile, baseY: tile.minY + 300, height: 150, count: 16, seed: 7, dark: true)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        emblem(ctx, center: CGPoint(x: 470, y: 590), width: 470)
        ctx.endTransparencyLayer()
        blades(ctx, tile, baseY: tile.minY + 140, height: 160, count: 13, seed: 42, dark: false)
        ctx.restoreGState()
    }
} else if mode == "icon" {
    rep = render(size: CGSize(width: 1024, height: 1024)) { ctx in
        // Apple icon grid: 824x824 rounded square centered in 1024 canvas
        let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
        let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
        ctx.addPath(shape); ctx.setFillColor(color(0x000000)); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(shape); ctx.clip()
        gradientFill(ctx, tile)
        // emblem drawn in its own transparency layer so the slash cut-out only cuts the emblem
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        emblem(ctx, center: CGPoint(x: 490, y: 530), width: 560)
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }
} else {
    let size = CGSize(width: 1000, height: 1700)
    rep = render(size: size) { ctx in
        let r = CGRect(origin: .zero, size: size)
        gradientFill(ctx, r)
        ctx.setAlpha(0.28)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        emblem(ctx, center: CGPoint(x: size.width * 0.52, y: size.height * 0.40), width: size.width * 0.80)
        ctx.endTransparencyLayer()
    }
}
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
