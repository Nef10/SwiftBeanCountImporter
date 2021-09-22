//
//  WealthsimpleImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2021-09-10.
//  Copyright © 2021 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel
import SwiftBeanCountWealthsimpleMapper
import Wealthsimple

protocol WealthsimpleDownloaderProvider {
    init(authenticationCallback: @escaping WealthsimpleDownloader.AuthenticationCallback, credentialStorage: CredentialStorage)
    func authenticate(completion: @escaping (Error?) -> Void)
    func getAccounts(completion: @escaping (Result<[Wealthsimple.Account], Wealthsimple.AccountError>) -> Void)
    func getPositions(in account: Wealthsimple.Account, date: Date?, completion: @escaping (Result<[Wealthsimple.Position], Wealthsimple.PositionError>) -> Void)
    func getTransactions(
        in account: Wealthsimple.Account,
        startDate: Date?,
        completion: @escaping (Result<[Wealthsimple.Transaction], Wealthsimple.TransactionError>) -> Void
    )
}

class WealthsimpleImporter: BaseImporter, DownloadImporter {

    override class var importerName: String { "Wealthsimple" }
    override class var importerType: String { "wealthsimple" }
    override class var helpText: String {
        """
        TODO
        """
    }

    override var importName: String { "Wealthsimple Download" }
    var downloaderClass: WealthsimpleDownloaderProvider.Type = WealthsimpleDownloader.self

    private let existingLedger: Ledger
    private let sixtyTwoDays = -60 * 60 * 24 * 364.0

    private var downloader: WealthsimpleDownloaderProvider!
    private var mapper: WealthsimpleLedgerMapper

    private var downloadedAccounts = [Wealthsimple.Account]()

    /// Results
    private var transactions = [ImportedTransaction]()
    private var balances = [Balance]()
    private var prices = [Price]()

    override required init(ledger: Ledger?) {
        existingLedger = ledger ?? Ledger()
        mapper = WealthsimpleLedgerMapper(ledger: existingLedger)
        super.init(ledger: ledger)
    }

    override func load() {
        downloader = downloaderClass.init(authenticationCallback: authenticationCallback, credentialStorage: self)

        let group = DispatchGroup()
        group.enter()

        download {
            group.leave()
        }

        group.wait()
    }

    private func download(_ completion: @escaping () -> Void) {
        downloader.authenticate { error in
            if let error = error {
                self.delegate?.error(error)
                completion()
            } else {
                self.downloadAccounts(completion)
            }
        }
    }

    private func downloadAccounts(_ completion: @escaping () -> Void) {
        downloader.getAccounts { result in
            switch result {
            case let .failure(error):
                self.delegate?.error(error)
                completion()
            case let .success(accounts):
                self.downloadedAccounts = accounts
                self.mapper.accounts = accounts
                DispatchQueue.global(qos: .userInitiated).async {
                    self.downloadPositions(completion)
                }
            }
        }
    }

    private func downloadPositions(_ completion: @escaping () -> Void) {
        let group = DispatchGroup()
        var errorOccurred = false

        downloadedAccounts.forEach { account in
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                self.downloader.getPositions(in: account, date: nil) { result in
                    switch result {
                    case let .failure(error):
                        self.delegate?.error(error)
                        errorOccurred = true
                        group.leave()
                        completion()
                    case let .success(positions):
                        do {
                            defer {
                                group.leave()
                            }
                            let (accountPrices, accountBalances) = try self.mapper.mapPositionsToPriceAndBalance(positions)
                            self.prices.append(contentsOf: accountPrices)
                            self.balances.append(contentsOf: accountBalances)
                        } catch {
                            self.delegate?.error(error)
                            errorOccurred = true
                            completion()
                        }
                    }
                }
            }
        }

        group.wait()
        if !errorOccurred {
            self.downloadTransactions(completion)
        }
    }

    private func downloadTransactions(_ completion: @escaping () -> Void) {
        let group = DispatchGroup()
        var downloadedTransactions = [SwiftBeanCountModel.Transaction]()
        var errorOccurred = false

        downloadedAccounts.forEach { account in
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                self.downloader.getTransactions(in: account, startDate: Date(timeIntervalSinceNow: self.sixtyTwoDays )) { result in
                    switch result {
                    case let .failure(error):
                        self.delegate?.error(error)
                        errorOccurred = true
                        group.leave()
                        completion()
                    case let .success(transactions):
                        do {
                            defer {
                                group.leave()
                            }
                            let (accountPrices, accountTransactions) = try self.mapper.mapTransactionsToPriceAndTransactions(transactions)
                            self.prices.append(contentsOf: accountPrices)
                            downloadedTransactions.append(contentsOf: accountTransactions)
                        } catch {
                            self.delegate?.error(error)
                            errorOccurred = true
                            completion()
                        }
                    }
                }
            }
        }

        group.wait()
        if !errorOccurred {
            self.mapTransactions(downloadedTransactions, completion)
        }
    }

    private func mapTransactions(_ transactions: [SwiftBeanCountModel.Transaction], _ completion: @escaping () -> Void) {
        self.transactions = transactions.map {
            if $0.postings.contains(where: { $0.accountName == WealthsimpleLedgerMapper.fallbackExpenseAccountName }) {
                return ImportedTransaction($0,
                                           shouldAllowUserToEdit: true,
                                           accountName: $0.postings.first { $0.accountName != WealthsimpleLedgerMapper.fallbackExpenseAccountName }!.accountName)
            }
            return ImportedTransaction($0)
        }
        completion()
    }

    override func nextTransaction() -> ImportedTransaction? {
        guard !transactions.isEmpty else {
            return nil
        }
        return transactions.removeFirst()
    }

    override func balancesToImport() -> [Balance] {
       balances
    }

    override func pricesToImport() -> [Price] {
        prices
    }

    private func authenticationCallback(callback: @escaping ((String, String, String) -> Void)) {
        var username, password, otp: String!

        let group = DispatchGroup()
        group.enter()

        delegate?.requestInput(name: "Username", suggestions: [], isSecret: false) {
            username = $0
            group.leave()
            return true
        }
        group.wait()
        group.enter()
        delegate?.requestInput(name: "Password", suggestions: [], isSecret: true) {
            password = $0
            group.leave()
            return true
        }
        group.wait()
        group.enter()
        delegate?.requestInput(name: "OTP", suggestions: [], isSecret: false) {
            otp = $0
            group.leave()
            return true
        }
        group.wait()
        callback(username, password, otp)
    }

}

extension WealthsimpleImporter: CredentialStorage {

    func save(_ value: String, for key: String) {
        self.delegate?.saveCredential(value, for: "\(Self.importerType)-\(key)")
    }

    func read(_ key: String) -> String? {
        self.delegate?.readCredential("\(Self.importerType)-\(key)")
    }

}

extension WealthsimpleDownloader: WealthsimpleDownloaderProvider {
}
