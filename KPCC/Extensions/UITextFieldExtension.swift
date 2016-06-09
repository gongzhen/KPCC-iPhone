//
//  UITextFieldExtension.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/9/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import UIKit

extension UITextField {

    var alertController: UIAlertController? {
        var responder = nextResponder()
        while responder != nil {
            if let alertController = responder as? UIAlertController {
                return alertController
            }
            responder = responder?.nextResponder()
        }
        return nil
    }

}
