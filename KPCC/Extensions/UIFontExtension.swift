//
//  UIFontExtension.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/3/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

enum FreightSansPro: UInt {

    case Light
    case LightItalic
    case Book
    case BookItalic
    case Medium
    case MediumItalic
    case Semibold
    case SemiboldItalic
    case Bold
    case BoldItalic
    case Black
    case BlackItalic

    var name: String {
        return UIFont.freightSansProName(self)
    }

}

extension UIFont {

    static func freightSansProName(freightSansPro: FreightSansPro) -> String {
        switch freightSansPro {
        case .Light:
            return "FreightSansProLight-Regular"
        case .LightItalic:
            return "FreightSansProLight-Italic"
        case .Book:
            return "FreightSansProBook-Regular"
        case .BookItalic:
            return "FreightSansProBook-Italic"
        case .Medium:
            return "FreightSansProMedium-Regular"
        case .MediumItalic:
            return "FreightSansProMedium-Italic"
        case .Semibold:
            return "FreightSansProSemibold-Regular"
        case .SemiboldItalic:
            return "FreightSansProSemibold-Italic"
        case .Bold:
            return "FreightSansProBold-Regular"
        case .BoldItalic:
            return "FreightSansProBold-Italic"
        case .Black:
            return "FreightSansProBlack-Regular"
        case .BlackItalic:
            return "FreightSansProBlack-Italic"
        }
    }

}
