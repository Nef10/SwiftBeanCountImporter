//
//  WealthsimpleImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2021-09-20.
//  Copyright © 2021 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import Wealthsimple
import XCTest

protocol EquatableError: Error, Equatable {
}

struct TestError: EquatableError {
    let id = UUID()
}

class ErrorDelegate<T: EquatableError>: BaseTestImporterDelegate {
    let error: T
    var verified = false

    init(error: T) {
        self.error = error
    }

    override func error(_ error: Error) {
        XCTAssertEqual(error as? T, self.error)
        verified = true
    }
}

class CredentialDelegate: BaseTestImporterDelegate {
    var verifiedSave = false
    var verifiedRead = false

    override func saveCredential(_ value: String, for key: String) {
        XCTAssertEqual(key, "wealthsimple-testKey2")
        XCTAssertEqual(value, "testValue")
        verifiedSave = true
    }

    override func readCredential(_ key: String) -> String? {
        XCTAssertEqual(key, "wealthsimple-testKey")
        verifiedRead = true
        return nil
    }
}

struct TestAccount: Wealthsimple.Account {
    var accountType = Wealthsimple.AccountType.nonRegistered
    var currency = "CAD"
    var id = "id123"
    var number = "A1B2"
}

class AuthenticationDelegate: BaseTestImporterDelegate {
    let names = ["Username", "Password", "OTP"]
    let secrets = [false, true, false]

    var verified = false
    var index = 0

    override func requestInput(name: String, suggestions: [String], isSecret: Bool, completion: (String) -> Bool) {
        XCTAssertEqual(name, names[index])
        XCTAssert(suggestions.isEmpty)
        XCTAssertEqual(isSecret, secrets[index])
        switch index {
        case 0:
            XCTAssert(completion("testUserName"))
        case 1:
            XCTAssert(completion("testPassword"))
        case 2:
            XCTAssert(completion("testOTP"))
            verified = true
        default:
            XCTFail("Caled requestInput too often")
        }
        index += 1
    }
}

final class WealthsimpleImporterTests: XCTestCase {

    private struct TestDownloader: WealthsimpleDownloaderProvider {

        init(authenticationCallback: @escaping WealthsimpleDownloader.AuthenticationCallback, credentialStorage: CredentialStorage) {
            WealthsimpleImporterTests.authenticationCallback = authenticationCallback
            WealthsimpleImporterTests.credentialStorage = credentialStorage
            downloader = self
        }

        func authenticate(completion: @escaping (Error?) -> Void) {
            completion(WealthsimpleImporterTests.authenticate?())
        }

        func getAccounts(completion: @escaping (Result<[Wealthsimple.Account], Wealthsimple.AccountError>) -> Void) {
            completion(WealthsimpleImporterTests.getAccounts?() ?? .success([]))
        }

        func getPositions(in account: Wealthsimple.Account, date: Date?, completion: @escaping (Result<[Position], PositionError>) -> Void) {
            completion(WealthsimpleImporterTests.getPositions?(account, date) ?? .success([]))
        }

        func getTransactions(
            in account: Wealthsimple.Account,
            startDate: Date?,
            completion: @escaping (Result<[Wealthsimple.Transaction], Wealthsimple.TransactionError>) -> Void
        ) {
            completion(WealthsimpleImporterTests.getTransactions?(account, startDate) ?? .success([]))
        }
    }

    private static var downloader: TestDownloader!
    private static var authenticate: (() -> Error?)?
    private static var getAccounts: (() -> Result<[Wealthsimple.Account], Wealthsimple.AccountError>)?
    private static var getPositions: ((Wealthsimple.Account, Date?) -> Result<[Position], PositionError>)?
    private static var getTransactions: ((Wealthsimple.Account, Date?) -> Result<[Wealthsimple.Transaction], TransactionError>)?
    private static var authenticationCallback: WealthsimpleDownloader.AuthenticationCallback!
    private static var credentialStorage: CredentialStorage!

    override func setUpWithError() throws {
        Self.downloader = nil
        Self.authenticate = nil
        Self.getAccounts = nil
        Self.getPositions = nil
        Self.getTransactions = nil
        Self.authenticationCallback = nil
        Self.credentialStorage = nil
        try super.setUpWithError()
    }

    func testImporterName() {
        XCTAssertEqual(WealthsimpleImporter.importerName, "Wealthsimple")
    }

    func testImporterType() {
        XCTAssertEqual(WealthsimpleImporter.importerType, "wealthsimple")
    }

    func testHelpText() {
        XCTAssertEqual(WealthsimpleImporter.helpText,
                       "TODO")
    }

    func testImportName() {
        XCTAssertEqual(WealthsimpleImporter(ledger: nil).importName, "Wealthsimple Download")
    }

    func testNoData() {
        let importer = WealthsimpleImporter(ledger: nil)
        importer.downloaderClass = TestDownloader.self
        importer.load()
        XCTAssertNil(importer.nextTransaction())
        XCTAssert(importer.balancesToImport().isEmpty)
        XCTAssert(importer.pricesToImport().isEmpty)
    }

    func testLoadAuthenticationError() {
        let importer = WealthsimpleImporter(ledger: nil)
        let error = TestError()
        let delegate = ErrorDelegate(error: error)
        Self.authenticate = { error }
        importer.delegate = delegate
        importer.downloaderClass = TestDownloader.self
        importer.load()
        XCTAssert(delegate.verified)
    }

    func testLoadAccountError() {
        let importer = WealthsimpleImporter(ledger: nil)
        let error = AccountError.httpError(error: "TESTErrorString")
        let delegate = ErrorDelegate(error: error)
        Self.getAccounts = { .failure(error) }
        importer.delegate = delegate
        importer.downloaderClass = TestDownloader.self
        importer.load()
        XCTAssert(delegate.verified)
    }

    func testLoadAccount() {
        let importer = WealthsimpleImporter(ledger: nil)
        var verified = false
        let account = TestAccount()
        Self.getAccounts = { .success([account]) }
        Self.getPositions = { requestedAccount, _ in
            XCTAssertEqual(requestedAccount.id, account.id)
            XCTAssertEqual(requestedAccount.number, account.number)
            verified = true
            return .success([])
        }
        importer.downloaderClass = TestDownloader.self
        importer.load()
        XCTAssert(verified)
        XCTAssertNil(importer.nextTransaction())
        XCTAssert(importer.balancesToImport().isEmpty)
        XCTAssert(importer.pricesToImport().isEmpty)
    }

    func testCredentialStorage() {
        let importer = WealthsimpleImporter(ledger: nil)
        let delegate = CredentialDelegate()
        importer.delegate = delegate
        importer.downloaderClass = TestDownloader.self
        importer.load()
        _ = Self.credentialStorage.read("testKey")
        XCTAssert(delegate.verifiedRead)
        XCTAssertFalse(delegate.verifiedSave)
        Self.credentialStorage.save("testValue", for: "testKey2")
        XCTAssert(delegate.verifiedSave)
    }

    func testAuthenticationCallback() {
        let expectation = XCTestExpectation(description: "authenticationCallback called")
        let importer = WealthsimpleImporter(ledger: nil)
        let delegate = AuthenticationDelegate()
        importer.delegate = delegate
        importer.downloaderClass = TestDownloader.self
        importer.load()
        Self.authenticationCallback {
            XCTAssertEqual($0, "testUserName")
            XCTAssertEqual($1, "testPassword")
            XCTAssertEqual($2, "testOTP")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
        XCTAssert(delegate.verified)
    }

}

extension Wealthsimple.AccountError: EquatableError {
    public static func == (lhs: Wealthsimple.AccountError, rhs: Wealthsimple.AccountError) -> Bool {
        switch (lhs, rhs) {
        case let (.httpError(lhsString), .httpError(rhsString)):
            return lhsString == rhsString
        case let (.invalidJson(lhsString), .invalidJson(rhsString)):
            return lhsString == rhsString
        default:
            return false
        }
    }

}
