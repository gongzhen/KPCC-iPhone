//
//  NSMutableURLRequestExtension.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/10/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import Foundation

extension NSMutableURLRequest {

    convenience init(URL: NSURL, HTTPMethod: String) {
        self.init(URL: URL)
        self.HTTPMethod = HTTPMethod
    }

    func setHTTPBodyWithDictionary(dictionary: [String: String]) {
        var parts = [String]()
        for (k, v) in dictionary {
            parts.append("\(k.URLQueryEncodedString)=\(v.URLQueryEncodedString)")
        }
        HTTPBody = parts.joinWithSeparator("&").dataUsingEncoding(NSUTF8StringEncoding)
    }

}
