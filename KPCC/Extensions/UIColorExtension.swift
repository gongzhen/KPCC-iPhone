//
//  UIColorExtension.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/3/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import UIKit

extension UIColor {

    convenience init(r: UInt, g: UInt, b: UInt, a: Double) {

        let red = (CGFloat(r) / 255.0)
        let green = (CGFloat(g) / 255.0)
        let blue = (CGFloat(b) / 255.0)
        let alpha = CGFloat(a)

        self.init(
            red: clamp(0.0, red, 1.0),
            green: clamp(0.0, green, 1.0),
            blue: clamp(0.0, blue, 1.0),
            alpha: clamp(0.0, alpha, 1.0)
        )

    }

    convenience init(r: UInt, g: UInt, b: UInt) {
        self.init(r: r, g: g, b: b, a: 1.0)
    }

}
