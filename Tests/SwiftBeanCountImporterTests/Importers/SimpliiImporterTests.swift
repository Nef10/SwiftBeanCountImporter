//
//  SimpliiImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-07.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

final class SimpliiImporterTests: XCTestCase {

    func testHeaders() {
        XCTAssertEqual(SimpliiImporter.headers, [["Date", "Transaction Details", "Funds Out", "Funds In"]])
    }

    func testImporterName() {
        XCTAssertEqual(SimpliiImporter.importerName, "Simplii")
    }

    func testImporterType() {
        XCTAssertEqual(SimpliiImporter.importerType, "simplii")
    }

    func testHelpText() {
        XCTAssertEqual(SimpliiImporter.helpText,
                       "Enables importing of downloaded CSV files from Simplii Accounts.\n\nTo use add importer-type: \"simplii\" to your account.")
    }

    func testImportName() throws {
        XCTAssertEqual(SimpliiImporter(ledger: nil, csvReader: try TestUtils.csvReader(content: "A"), fileName: "TestName").importName, "Simplii File TestName")
    }

    func testParseLine() throws {
        let importer = SimpliiImporter(ledger: nil,
                                       csvReader: try TestUtils.csvReader(content: """
Date, Transaction Details, Funds Out, Funds In
06/10/2017,PAYROLL DEPOSIT COMPANY INC.,,123.45\n
"""
                                            ),
                                       fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "PAYROLL DEPOSIT COMPANY INC.")
        XCTAssertEqual(line.amount, Decimal(string: "123.45", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineAmountOut() throws {
        let importer = SimpliiImporter(ledger: nil,
                                       csvReader: try TestUtils.csvReader(content: """
Date, Transaction Details, Funds Out, Funds In
05/06/2020,BANK TO BANK TSF EXT TSF,1234.56,\n
"""
                                            ),
                                       fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "BANK TO BANK TSF EXT TSF")
        XCTAssertEqual(line.amount, Decimal(string: "-1234.56", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineInterest() throws {
        let importer = SimpliiImporter(ledger: nil,
                                       csvReader: try TestUtils.csvReader(content: """
Date, Transaction Details, Funds Out, Funds In
06/05/2020, INTEREST,,0.69\n
"""
                                            ),
                                       fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20200605))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "INTEREST")
        XCTAssertEqual(line.amount, Decimal(string: "0.69", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "Simplii")
        XCTAssertNil(line.price)
    }

}
