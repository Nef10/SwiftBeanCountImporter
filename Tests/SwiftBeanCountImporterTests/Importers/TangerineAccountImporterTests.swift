//
//  TangerineAccountImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-07.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

final class TangerineAccountImporterTests: XCTestCase {

    func testHeaders() {
        XCTAssertEqual(TangerineAccountImporter.headers,
                       [["Date", "Transaction", "Name", "Memo", "Amount"]])
    }

    func testImporterName() {
        XCTAssertEqual(TangerineAccountImporter.importerName, "Tangerine Accounts")
    }

    func testImporterType() {
        XCTAssertEqual(TangerineAccountImporter.importerType, "tangerine-account")
    }

    func testHelpText() {
        XCTAssertEqual(TangerineAccountImporter.helpText,
                       "Enables importing of downloaded CSV files from Tangerine Accounts.\n\nTo use add importer-type: \"tangerine-account\" to your account.")
    }

    func testImportName() throws {
        XCTAssertEqual(TangerineAccountImporter(ledger: nil, csvReader: try TestUtils.csvReader(content: "A"), fileName: "TestName").importName,
                       "Tangerine Account File TestName")
    }

    func testAccountsFromLedger() {
        var importer = TangerineAccountImporter(ledger: TestUtils.lederAccountNumers,
                                                csvReader: TestUtils.basicCSVReader,
                                                fileName: "Export \(TestUtils.accountNumberChequing).csv")
        var possibleAccountNames = importer.accountsFromLedger()
        XCTAssertEqual(possibleAccountNames.count, 1)
        XCTAssertEqual(possibleAccountNames[0], TestUtils.chequing)

        importer = TangerineAccountImporter(ledger: TestUtils.lederAccountNumers, csvReader: TestUtils.basicCSVReader, fileName: "Export \(TestUtils.accountNumberCash).csv")
        possibleAccountNames = importer.accountsFromLedger()
        XCTAssertEqual(possibleAccountNames.count, 1)
        XCTAssertEqual(possibleAccountNames[0], TestUtils.cash)

        importer = TangerineAccountImporter(ledger: TestUtils.lederAccountNumers, csvReader: TestUtils.basicCSVReader, fileName: "Export 000000.csv")
        possibleAccountNames = importer.accountsFromLedger()
        XCTAssertEqual(possibleAccountNames.count, 2)
        XCTAssertTrue(possibleAccountNames.contains(TestUtils.cash))
        XCTAssertTrue(possibleAccountNames.contains(TestUtils.chequing))
    }

    func testAccountSuggestions() {
        var importer = TangerineAccountImporter(ledger: TestUtils.lederAccountNumers,
                                                csvReader: TestUtils.basicCSVReader,
                                                fileName: "Export \(TestUtils.accountNumberChequing).csv")
        importer.delegate = TestUtils.noInputDelegate
        XCTAssertEqual(importer.configuredAccountName, TestUtils.chequing)

        importer = TangerineAccountImporter(ledger: TestUtils.lederAccountNumers, csvReader: TestUtils.basicCSVReader, fileName: "Export \(TestUtils.accountNumberCash).csv")
        importer.delegate = TestUtils.noInputDelegate
        XCTAssertEqual(importer.configuredAccountName, TestUtils.cash)

        importer = TangerineAccountImporter(ledger: TestUtils.lederAccountNumers, csvReader: TestUtils.basicCSVReader, fileName: "Export 000000.csv")
        let delegate = AccountNameSuggestionVerifier(expectedValues: [TestUtils.cash, TestUtils.chequing])
        importer.delegate = delegate
        _ = importer.configuredAccountName
        XCTAssert(delegate.verified)
    }

    func testParseLine() throws {
        let importer = TangerineAccountImporter(ledger: nil,
                                                csvReader: try TestUtils.csvReader(content: """
Date,Transaction,Name,Memo,Amount
6/5/2020,OTHER,EFT Withdrawal to BANK,To BANK,-765.43\n
"""
                                            ),
                                                fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20200605))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "To BANK")
        XCTAssertEqual(line.amount, Decimal(string: "-765.43", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineEmptyMemo() throws {
        let importer = TangerineAccountImporter(ledger: nil,
                                                csvReader: try TestUtils.csvReader(content: """
Date,Transaction,Name,Memo,Amount
6/10/2017,DEBIT,Cheque Withdrawal - 002,,-95\n
"""
                                            ),
                                                fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssert(Calendar.current.isDate(line.date, inSameDayAs: TestUtils.date20170610))
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Cheque Withdrawal - 002")
        XCTAssertEqual(line.amount, Decimal(string: "-95.00", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

    func testParseLineInterest() throws {
        let importer = TangerineAccountImporter(ledger: nil,
                                                csvReader: try TestUtils.csvReader(content: """
Date,Transaction,Name,Memo,Amount
5/31/2020,OTHER,Interest Paid,,0.5\n
"""
                                            ),
                                                fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "Interest Paid")
        XCTAssertEqual(line.amount, Decimal(string: "0.50", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "Tangerine")
        XCTAssertNil(line.price)
    }

    func testParseLineInterac() throws {
        let importer = TangerineAccountImporter(ledger: nil,
                                                csvReader: try TestUtils.csvReader(content: """
Date,Transaction,Name,Memo,Amount
5/23/2020,OTHER,INTERAC e-Transfer From: NAME,Transferred,40.25\n
"""
                                            ),
                                                fileName: "")

        importer.csvReader.next()
        let line = importer.parseLine()
        XCTAssertEqual(line.description.trimmingCharacters(in: .whitespaces), "NAME - Transferred")
        XCTAssertEqual(line.amount, Decimal(string: "40.25", locale: Locale(identifier: "en_CA"))!)
        XCTAssertEqual(line.payee, "")
        XCTAssertNil(line.price)
    }

}
