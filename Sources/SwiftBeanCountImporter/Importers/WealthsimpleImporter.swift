//
//  WealthsimpleImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2021-09-10.
//  Copyright © 2021 Steffen Kötte. All rights reserved.
//

import Combine
import Foundation
import SwiftBeanCountModel
import SwiftBeanCountWealthsimpleMapper
import Wealthsimple

class WealthsimpleImporter: BaseImporter, DownloadImporter {

    override class var importerName: String { "Wealthsimple" }
    override class var importerType: String { "wealthsimple" }
    override class var helpText: String {
        """
        TODO
        """
    }

    override var importName: String { "Wealthsimple Download" }

    private let existingLedger: Ledger
    private let sixtyTwoDays = -60 * 60 * 24 * 62.0
    private let positionPublisher = PassthroughSubject<[Position], Position.PositionError>()
    private let transactionPublisher = PassthroughSubject<[Wealthsimple.Transaction], Wealthsimple.Transaction.TransactionError>()

    private var downloader: WealthsimpleDownloader!
    private var mapper: WealthsimpleLedgerMapper

    private var downloadedAccounts = [Wealthsimple.Account]()

    private var positionSubscription: AnyCancellable?
    private var transactionSubscription: AnyCancellable?
    /// Results
    private var transactions = [ImportedTransaction]()
    private var balances = [Balance]()
    private var prices = [Price]()

    required init(ledger: Ledger) {
        existingLedger = ledger
        mapper = WealthsimpleLedgerMapper(ledger: ledger)
        super.init(ledger: ledger)
    }

    override func load() {
        downloader = WealthsimpleDownloader(authenticationCallback: authenticationCallback, credentialStorage: self)

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
                self.downloadPositions(completion)
            }
        }
    }

    private func downloadPositions(_ completion: @escaping () -> Void) {
        positionSubscription = positionPublisher
            .tryMap { value -> ([Price], [Balance]) in
                try self.mapper.mapPositionsToPriceAndBalance(value)
            }
            .collect(downloadedAccounts.count)
            .sink(receiveCompletion: { receivedCompletion in
                if case let .failure(error) = receivedCompletion {
                    self.delegate?.error(error)
                }
                completion()
            }, receiveValue: { values in
                for (accountPrices, accountBalances) in values {
                    self.prices.append(contentsOf: accountPrices)
                    self.balances.append(contentsOf: accountBalances)
                }
                self.downloadTransactions(completion)
            })

        downloadedAccounts.forEach { account in
            DispatchQueue.global(qos: .userInitiated).async {
                self.downloader.getPositions(in: account, date: nil) { result in
                    switch result {
                    case let .failure(error):
                        self.positionPublisher.send(completion: .failure(error))
                    case let .success(positions):
                        self.positionPublisher.send(positions)
                    }
                }
            }
        }
    }

    private func downloadTransactions(_ completion: @escaping () -> Void) {
        transactionSubscription = transactionPublisher
            .tryMap { value -> ([Price], [SwiftBeanCountModel.Transaction]) in
                try self.mapper.mapTransactionsToPriceAndTransactions(value)
            }
            .collect(downloadedAccounts.count)
            .sink(receiveCompletion: { receivedCompletion in
                if case let .failure(error) = receivedCompletion {
                    self.delegate?.error(error)
                }
                completion()
            }, receiveValue: { values in
                var downloadedTransactions = [SwiftBeanCountModel.Transaction]()
                for (accountPrices, accountTransactions) in values {
                    self.prices.append(contentsOf: accountPrices)
                    downloadedTransactions.append(contentsOf: accountTransactions)
                }
                self.mapTransactions(downloadedTransactions, completion)
            })

        downloadedAccounts.forEach { account in
            DispatchQueue.global(qos: .userInitiated).async {
                self.downloader.getTransactions(in: account, startDate: Date(timeIntervalSinceNow: self.sixtyTwoDays )) { result in
                    switch result {
                    case let .failure(error):
                        self.transactionPublisher.send(completion: .failure(error))
                    case let .success(transactions):
                        self.transactionPublisher.send(transactions)
                    }
                }
            }
        }
    }

    private func mapTransactions(_ transactions: [SwiftBeanCountModel.Transaction], _ completion: @escaping () -> Void) {
        self.transactions = transactions.map {
            ImportedTransaction(transaction: $0, originalDescription: "", possibleDuplicate: nil, shouldAllowUserToEdit: false, accountName: nil)
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
