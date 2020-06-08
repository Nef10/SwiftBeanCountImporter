//
//  RogersImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-07.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

final class RogersImporterTests: XCTestCase {

    func testHeader() {
        XCTAssertEqual(RogersImporter.header,
                       ["Date", "Activity Type", "Merchant Name", "Merchant Category Description", "Amount", "Rewards"])
    }

    func testSettingsName() {
        XCTAssertEqual(RogersImporter.settingsName, "Rogers CC")
    }

    func testParseLine() {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: TestUtils.csvReader(content: """
"Date","Activity Type","Merchant Name","Merchant Category Description","Amount","Rewards"
"2017-06-10","TRANS","Merchant","Catalog Merchant","4.44",""\n
"""
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Merchant")
        XCTAssertEqual(line.amount, Decimal(string: "-4.44", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineCashBack() {
        let importer = RogersImporter(ledger: nil,
                                      csvReader: TestUtils.csvReader(content: """
"Date","Activity Type","Merchant Name","Merchant Category Description","Amount","Rewards"
"2020-06-05","TRANS","CashBack / Remises","","-43.00",""\n
"""
                                            ),
                                      fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20200605))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "CashBack / Remises")
        XCTAssertEqual(line.amount, Decimal(string: "43.00", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "Rogers")
        XCTAssertNil(line.price)
    }

}
