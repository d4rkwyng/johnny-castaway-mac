//
//  Johnny Castaway for macOS
//  GPL-3.0-or-later; see LICENSE.
//

import CoreGraphics
import Foundation
import JohnnyEngine

public enum FrameImage {

    /// Wraps a presented 640×480 RGBA frame in a CGImage (one copy).
    public static func make(_ pixels: [Pixel]) -> CGImage? {
        let data = pixels.withUnsafeBytes { Data($0) }
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: Layer.width, height: Layer.height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: Layer.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.noneSkipLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent)
    }
}
