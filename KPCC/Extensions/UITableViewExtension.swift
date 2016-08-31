//
//  UITableViewExtension.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/8/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import UIKit

extension UITableView {

    private class Value1TableViewCell: UITableViewCell {

        override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
            super.init(style: .Value1, reuseIdentifier: String(Value1TableViewCell))
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }

    }

    private class Value2TableViewCell: UITableViewCell {

        override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
            super.init(style: .Value2, reuseIdentifier: String(Value2TableViewCell))
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }

    }

    private class SubtitleTableViewCell: UITableViewCell {

        override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
            super.init(style: .Subtitle, reuseIdentifier: String(SubtitleTableViewCell))
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }

    }

    func registerClass(style style: UITableViewCellStyle) {
        switch style {
        case .Value1:
            registerClass(
                Value1TableViewCell.self,
                forCellReuseIdentifier: String(Value1TableViewCell)
            )
        case .Value2:
            registerClass(
                Value2TableViewCell.self,
                forCellReuseIdentifier: String(Value2TableViewCell)
            )
        case .Subtitle:
            registerClass(
                SubtitleTableViewCell.self,
                forCellReuseIdentifier: String(SubtitleTableViewCell)
            )
        default:
            registerClass(
                UITableViewCell.self,
                forCellReuseIdentifier: String(UITableViewCell)
            )
        }
    }

    func dequeueReusableCell(style style: UITableViewCellStyle) -> UITableViewCell {
        switch style {
        case .Value1:
            return dequeueReusableCellWithIdentifier(String(Value1TableViewCell))!
        case .Value2:
            return dequeueReusableCellWithIdentifier(String(Value2TableViewCell))!
        case .Subtitle:
            return dequeueReusableCellWithIdentifier(String(SubtitleTableViewCell))!
        default:
            return dequeueReusableCellWithIdentifier(String(UITableViewCell))!
        }
    }

}
