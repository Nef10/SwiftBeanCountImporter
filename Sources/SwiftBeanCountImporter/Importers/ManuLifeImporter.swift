//
//  ManuLifeImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2019-09-08.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

class ManuLifeImporter: BaseImporter, TransactionBalanceTextImporter {

    private struct ManuLifeBalance {
        let commodity: String
        let unitValue: String
        let employeeBasic: String?
        let employeeVoluntary: String?
        let employerMatch: String?
        let employerBasic: String?
    }

    private struct ManuLifeBuy {
        let commodity: String
        let units: String
        let price: String
        let total: String
    }

    override class var importerType: String { "manulife" }

    /// DateFormatter to parse the date from the input
    private static let importDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "MMMM d, yyyy"
        return dateFormatter
    }()

    private var date: Date {
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        dateComponents.hour = 0
        dateComponents.minute = 0
        dateComponents.second = 0
        return Calendar.current.date(from: dateComponents)!
    }

    private let defaultContribution = 1.0
    private let unitFormat = "%.5f"

    // Input
    private let transactionInputString: String
    private let balanceInputString: String

    private var accountString: String { configuredAccountName.fullName.split(separator: ":").dropLast(1).joined(separator: ":") }
    private var account: Account? { ledger?.accounts.first { $0.name == configuredAccountName } }
    private var employeeBasicFraction: Double { Double(account?.metaData["employee-basic-fraction"] ?? "") ?? defaultContribution }
    private var employerBasicFraction: Double { Double(account?.metaData["employer-basic-fraction"] ?? "") ?? defaultContribution }
    private var employerMatchFraction: Double { Double(account?.metaData["employer-match-fraction"] ?? "") ?? defaultContribution }
    private var employeeVoluntaryFraction: Double { Double(account?.metaData["employee-voluntary-fraction"] ?? "") ?? defaultContribution }

    // Results from parsing
    private var parsedManuLifeBalances = [ManuLifeBalance]()
    private var parsedManuLifeBuys = [ManuLifeBuy]()
    private var parsedTransactionDate: Date?

    // Results to return
    private var balances = [Balance]()
    private var prices = [Price]()

    private var didReturnTransaction = false

    override var importName: String {
        "ManuLife Text"
    }

    required init(ledger: Ledger?, transaction: String, balance: String) {
        transactionInputString = transaction
        balanceInputString = balance
        super.init(ledger: ledger)
    }

    override func load() {
        let commodities = ledger?.commodities.reduce(into: [String: String]()) {
            if let name = $1.metaData["name"] {
                $0[name] = $1.symbol
            }
        } ?? [:]
        if !transactionInputString.isEmpty {
            let (buys, date) = parsePurchase(string: transactionInputString, commodities: commodities)
            parsedManuLifeBuys = buys
            parsedTransactionDate = date
        }
        if !balanceInputString.isEmpty {
            parsedManuLifeBalances = parseBalances(string: balanceInputString, commodities: commodities)
        }
    }

    override func nextTransaction() -> ImportedTransaction? {
        guard !didReturnTransaction else {
            return nil
        }
        var (transaction, prices) = convertPurchase(parsedManuLifeBuys, on: parsedTransactionDate)
        let (balances, balancePrices) = convertBalances(parsedManuLifeBalances)
        prices.append(contentsOf: balancePrices)

        for balance in balances {
            if !(ledger?.accounts.flatMap { $0.balances }.contains(balance) ?? false) {
                self.balances.append(balance)
            }
        }
        for price in prices {
            if !(ledger?.prices.contains(price) ?? false) {
                self.prices.append(price)
            }
        }

        didReturnTransaction = true
        return transaction
    }

    override func balancesToImport() -> [Balance] {
        balances
    }
    override func pricesToImport() -> [Price] {
        prices
    }

    /// Parses a string into ManuLifeBalances
    ///
    /// - Parameters:
    ///   - string: input from website
    ///   - commodities: dictionary of name to account for commodities
    /// - Returns: ManuLifeBalances
    private func parseBalances(string: String, commodities: [String: String]) -> [ManuLifeBalance] {
        let unitValuePattern = #"\s*?(?:Employer Basic|Member Voluntary|Employee voluntary)\s*[0-9.]*\s*([0-9.]*)\s*[0-9.]*"#

        // swiftlint:disable force_try
        let commodityRegex = try! NSRegularExpression(pattern: #"\s*?(\d{4}\s*?-\s*?.*?[a-z]\d)\s*?$"#, options: [.anchorsMatchLines])
        let employeeBasicRegex = try! NSRegularExpression(pattern: #"\s*?Employee Basic\s*([0-9.]*)"#, options: [.anchorsMatchLines])
        let employeeVoluntaryRegex = try! NSRegularExpression(pattern: #"\s*?Employee voluntary\s*([0-9.]*)"#, options: [.anchorsMatchLines])
        let employerBasicRegex = try! NSRegularExpression(pattern: #"\s*?Employer Basic\s*([0-9.]*)"#, options: [.anchorsMatchLines])
        let employerMatchRegex = try! NSRegularExpression(pattern: #"\s*?Employer Match\s*([0-9.]*)"#, options: [.anchorsMatchLines])
        let unitValueRegex = try! NSRegularExpression(pattern: unitValuePattern, options: [.anchorsMatchLines])
        // swiftlint:enable force_try

        // Split by different Commodities
        let splittedInput = string.components(separatedBy: "TOTAL")

        // Get different Accounts for each Commodity
        var results = [ManuLifeBalance]()
        for input in splittedInput {
            guard var commodity = firstMatch(in: input, regex: commodityRegex), let unitValue = firstMatch(in: input, regex: unitValueRegex) else {
                continue
            }
            commodity = commodity.replacingOccurrences(of: " -", with: "")
            commodity = commodities[commodity] ?? commodity
            results.append(ManuLifeBalance(commodity: commodity,
                                           unitValue: unitValue,
                                           employeeBasic: firstMatch(in: input, regex: employeeBasicRegex),
                                           employeeVoluntary: firstMatch(in: input, regex: employeeVoluntaryRegex),
                                           employerMatch: firstMatch(in: input, regex: employerMatchRegex),
                                           employerBasic: firstMatch(in: input, regex: employerBasicRegex)))
        }

        return results
    }

    /// Converts ManuLifeBalance to SwiftBeanCountModel Balances and Prices
    private func convertBalances(_ manuLifeBalances: [ManuLifeBalance]) -> ([Balance], [Price]) {
        let balances: [Balance] = manuLifeBalances.flatMap { manuLifeBalance -> [Balance] in
            var tempBalances = [Balance]()
            if let amountString = manuLifeBalance.employeeBasic, let accountName = try? AccountName("\(accountString):Employee:Basic:\(manuLifeBalance.commodity)") {
                let (amountDecimal, decimalDigits) = ParserUtils.parseAmountDecimalFrom(string: amountString)
                let amount = Amount(number: amountDecimal, commoditySymbol: manuLifeBalance.commodity, decimalDigits: decimalDigits)
                tempBalances.append(Balance(date: date, accountName: accountName, amount: amount))
            }
            if let amountString = manuLifeBalance.employerBasic, let accountName = try? AccountName("\(accountString):Employer:Basic:\(manuLifeBalance.commodity)") {
                let (amountDecimal, decimalDigits) = ParserUtils.parseAmountDecimalFrom(string: amountString)
                let amount = Amount(number: amountDecimal, commoditySymbol: manuLifeBalance.commodity, decimalDigits: decimalDigits)
                tempBalances.append(Balance(date: date, accountName: accountName, amount: amount))
            }
            if let amountString = manuLifeBalance.employerMatch, let accountName = try? AccountName("\(accountString):Employer:Match:\(manuLifeBalance.commodity)") {
                let (amountDecimal, decimalDigits) = ParserUtils.parseAmountDecimalFrom(string: amountString)
                let amount = Amount(number: amountDecimal, commoditySymbol: manuLifeBalance.commodity, decimalDigits: decimalDigits)
                tempBalances.append(Balance(date: date, accountName: accountName, amount: amount))
            }
            if let amountString = manuLifeBalance.employeeVoluntary, let accountName = try? AccountName("\(accountString):Employee:Voluntary:\(manuLifeBalance.commodity)") {
                let (amountDecimal, decimalDigits) = ParserUtils.parseAmountDecimalFrom(string: amountString)
                let amount = Amount(number: amountDecimal, commoditySymbol: manuLifeBalance.commodity, decimalDigits: decimalDigits)
                tempBalances.append(Balance(date: date, accountName: accountName, amount: amount))
            }
            return tempBalances
        }

        let prices: [Price] = manuLifeBalances.compactMap { manuLifeBalance -> Price? in
            let (amountDecimal, decimalDigits) = ParserUtils.parseAmountDecimalFrom(string: manuLifeBalance.unitValue)
            let amount = Amount(number: amountDecimal, commoditySymbol: commoditySymbol, decimalDigits: decimalDigits)
            return try? Price(date: date, commoditySymbol: manuLifeBalance.commodity, amount: amount)
        }

        return (balances, prices)
    }

    /// Parses a string into ManuLifeBuys
    ///
    /// - Parameters:
    ///   - string: input from website
    ///   - commodities: dictionary of name to account for commodities
    /// - Returns: Tupel with ManuLifeBuys and the purchase date
    private func parsePurchase(string input: String, commodities: [String: String]) -> ([ManuLifeBuy], Date?) {
        let purchasePattern = #"\s*.*?\.gif\s*(\d{4}.*?[a-z]\d)\s*$\s*Contribution\s*([0-9.]*)\s*units\s*@\s*\$([0-9.]*)/unit\s*([0-9.]*)\s*$"#

        // swiftlint:disable force_try
        let dateRegex = try! NSRegularExpression(pattern: #"^(.*) Contribution \(Ref."#, options: [.anchorsMatchLines])
        let regex = try! NSRegularExpression(pattern: purchasePattern, options: [.anchorsMatchLines])
        // swiftlint:enable force_try

        // Parse purchase date
        let parsedDate = firstMatch(in: input, regex: dateRegex) ?? ""
        let date = Self.importDateFormatter.date(from: parsedDate)

        // Parse purchased units
        let fullRange = NSRange(input.startIndex..<input.endIndex, in: input)
        return (regex.matches(in: input, options: [], range: fullRange).compactMap { result -> ManuLifeBuy? in
            guard result.numberOfRanges == 5 else {
                return nil
            }
            var strings = [String]()
            for rangeNumber in 1..<result.numberOfRanges {
                let matchRange = result.range(at: rangeNumber)
                guard matchRange.location != NSNotFound, let range = Range(matchRange, in: input) else {
                    return nil
                }
                strings.append("\(input[range])")
            }
            let commodity = commodities[strings[0]] ?? strings[0]
            return ManuLifeBuy(commodity: commodity, units: strings[1], price: strings[2], total: strings[3])
        }, date)
    }

    /// Converts ManuLifeBuys to ImportedTransactions and SwiftBeanCountModel Prices
    private func convertPurchase(_ buys: [ManuLifeBuy], on date: Date?) -> (ImportedTransaction?, [Price]) {
        guard !buys.isEmpty, let date = date else {
            return (nil, [])
        }

        var totalAmount = Decimal()
        var postings = [Posting]()

        buys.forEach {
            let unitFraction = Double($0.units)! / (employeeBasicFraction + employerBasicFraction + employerMatchFraction + employeeVoluntaryFraction)
            let (buyAmount, _) = ParserUtils.parseAmountDecimalFrom(string: $0.total)
            totalAmount += buyAmount
            guard let cost = try? Cost(amount: ParserUtils.parseAmountFrom(string: $0.price, commoditySymbol: commoditySymbol), date: nil, label: nil) else {
                return
            }

            if employeeBasicFraction != 0, let accountName = try? AccountName("\(accountString):Employee:Basic:\($0.commodity)") {
                let amount = ParserUtils.parseAmountFrom(string: String(format: unitFormat, unitFraction * employeeBasicFraction), commoditySymbol: $0.commodity)
                postings.append(Posting(accountName: accountName, amount: amount, cost: cost))
            }
            if employerBasicFraction != 0, let accountName = try? AccountName("\(accountString):Employer:Basic:\($0.commodity)") {
                let amount = ParserUtils.parseAmountFrom(string: String(format: unitFormat, unitFraction * employerBasicFraction), commoditySymbol: $0.commodity)
                postings.append(Posting(accountName: accountName, amount: amount, cost: cost))
            }
            if employerMatchFraction != 0, let accountName = try? AccountName("\(accountString):Employer:Match:\($0.commodity)") {
                let amount = ParserUtils.parseAmountFrom(string: String(format: unitFormat, unitFraction * employerMatchFraction), commoditySymbol: $0.commodity)
                postings.append(Posting(accountName: accountName, amount: amount, cost: cost))
            }
            if employeeVoluntaryFraction != 0, let accountName = try? AccountName("\(accountString):Employee:Voluntary:\($0.commodity)") {
                let amount = ParserUtils.parseAmountFrom(string: String(format: unitFormat, unitFraction * employeeVoluntaryFraction), commoditySymbol: $0.commodity)
                postings.append(Posting(accountName: accountName, amount: amount, cost: cost))
            }
        }

        postings.insert(Posting(accountName: configuredAccountName, amount: Amount(number: -totalAmount, commoditySymbol: commoditySymbol, decimalDigits: 2)), at: 0)

        let prices: [Price] = buys.compactMap { manuLifeBuy -> Price? in
            try? Price(date: date, commoditySymbol: manuLifeBuy.commodity, amount: ParserUtils.parseAmountFrom(string: manuLifeBuy.price, commoditySymbol: commoditySymbol))
        }

        let transaction = Transaction(metaData: TransactionMetaData(date: date, payee: "", narration: "", flag: .complete, tags: []), postings: postings)
        let duplicate = getPossibleDuplicateFor(transaction)
        return (ImportedTransaction(transaction: transaction, originalDescription: "", possibleDuplicate: duplicate, shouldAllowUserToEdit: false, accountName: nil), prices)
    }

    /// Returns the first match of the capture group regex in the input string
    ///
    /// Checks that there is exactly one capture group.
    ///
    /// - Parameters:
    ///   - input: string to run regex on
    ///   - regex: regex
    /// - Returns: result of the capture group if found, nil otherwise
    private func firstMatch(in input: String, regex: NSRegularExpression) -> String? {
        let captureGroups = 1
        let fullRange = NSRange(input.startIndex..<input.endIndex, in: input)
        guard let result = regex.firstMatch(in: input, options: [], range: fullRange), result.numberOfRanges == 1 + captureGroups else {
            return nil
        }
        let captureGroupRange = result.range(at: captureGroups)
        guard captureGroupRange.location != NSNotFound, let range = Range(captureGroupRange, in: input) else {
            return nil
        }
        return "\(input[range])"
    }

}
