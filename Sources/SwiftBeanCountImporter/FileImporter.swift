//
//  FileImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2017-08-28.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

/// The FileImporterManager is responsible for the different types of `FileImporter`s.
/// It allow abstraction of the different importers by encapsulation to logic of which one to use.
public enum FileImporterManager {

    static var importers: [FileImporter.Type] {
        CSVImporterManager.importers
    }

    /// Returns a the correct FileImporter, or nil if the file cannot be imported
    /// - Parameters:
    ///   - ledger: existing ledger which is used to assist the import,
    ///             e.g. to read attributes of accounts
    ///   - url: URL of the file to import
    /// - Returns: FileImporter, or nil if the file cannot be imported
    public static func new(ledger: Ledger?, url: URL?) -> FileImporter? {
        CSVImporterManager.new(ledger: ledger, url: url)
    }

}

/// Struct describing a transaction which has been imported
public struct ImportedTransaction {

    /// Transaction which has been imported
    public let transaction: Transaction

    /// The original description from the file. This is used to allow saving
    /// of description and payee mapping.
    public let originalDescription: String

}

public protocol FileImporter: Importer {

    var accountName: AccountName? { get }
    var fileName: String { get }

    func loadFile()
    func parseLineIntoTransaction() -> ImportedTransaction?

}
