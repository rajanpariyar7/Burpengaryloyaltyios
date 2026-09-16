import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// Core Image replacements for the ZXing QR / Code 128 generation used on Android.
enum CodeGenerator {
    private static let context = CIContext()

    static func qrCode(from value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        return render(filter.outputImage, scale: 10)
    }

    static func barcode(from value: String) -> UIImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(value.utf8)
        filter.quietSpace = 2
        return render(filter.outputImage, scale: 4)
    }

    private static func render(_ image: CIImage?, scale: CGFloat) -> UIImage? {
        guard let image else { return nil }
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct QRCodeView: View {
    let value: String
    var size: CGFloat = 180

    var body: some View {
        codeImage(CodeGenerator.qrCode(from: value), width: size, height: size)
    }
}

struct BarcodeView: View {
    let value: String
    var height: CGFloat = 70

    var body: some View {
        codeImage(CodeGenerator.barcode(from: value), width: nil, height: height)
    }
}

@ViewBuilder
private func codeImage(_ image: UIImage?, width: CGFloat?, height: CGFloat) -> some View {
    if let image {
        Image(uiImage: image)
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: width, height: height)
    } else {
        RoundedRectangle(cornerRadius: 8)
            .fill(Palette.borderSlate)
            .frame(width: width, height: height)
            .overlay(Text("Code unavailable").font(.caption).foregroundColor(.gray))
    }
}
