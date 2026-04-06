//
//  UIIMage+AverageColor.swift
//  Retune
//
//  Created by Eliase Osmani on 2/11/26.
//

import UIKit
import CoreImage

extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        
        let extent = inputImage.extent
        let filter = CIFilter(name: "CIAreaAverage")
        filter?.setValue(inputImage, forKey:  kCIInputImageKey)
        filter?.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)
        
        guard let outputImage = filter?.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        
        return UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green:  CGFloat(bitmap[1]) / 255,
            blue:   CGFloat(bitmap[2]) / 255,
            alpha: 1
        )
    }
}
