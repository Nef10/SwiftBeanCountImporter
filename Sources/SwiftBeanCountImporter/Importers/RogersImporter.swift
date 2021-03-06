//
//  RogersImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2019-12-16.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation

class RogersImporter: CSVBaseImporter, CSVImporter {

    private static let description = "Merchant Name"
    private static let date = "Transaction Date"
    private static let amount = "Amount"

    static let header = [date, "Activity Type", description, "Merchant Category", amount]
    override class var settingsName: String { "Rogers CC" }

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    override func parseLine() -> CSVLine {
        let date = Self.dateFormatter.date(from: csvReader[Self.date]!)!
        let description = csvReader[Self.description]!
        let amountString = csvReader[Self.amount]!
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        let amount = Decimal(string: amountString, locale: Locale(identifier: "en_CA"))!
        let payee = description == "CashBack / Remises" ? "Rogers" : ""
        return CSVLine(date: date, description: description, amount: -amount, payee: payee, price: nil)
    }

}
