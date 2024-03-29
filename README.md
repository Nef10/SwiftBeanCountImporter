# SwiftBeanCountImporter

[![CI Status](https://github.com/Nef10/SwiftBeanCountImporter/workflows/CI/badge.svg?event=push)](https://github.com/Nef10/SwiftBeanCountImporter/actions?query=workflow%3A%22CI%22) [![Documentation percentage](https://nef10.github.io/SwiftBeanCountImporter/badge.svg)](https://nef10.github.io/SwiftBeanCountImporter/) [![License: MIT](https://img.shields.io/github/license/Nef10/SwiftBeanCountImporter)](https://github.com/Nef10/SwiftBeanCountImporter/blob/main/LICENSE) [![Latest version](https://img.shields.io/github/v/release/Nef10/SwiftBeanCountImporter?label=SemVer&sort=semver)](https://github.com/Nef10/SwiftBeanCountImporter/releases) ![platforms supported: linux | macOS | iOS | watchOS | tvOS](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-blue) ![SPM compatible](https://img.shields.io/badge/SPM-compatible-blue)

### ***This project is part for SwiftBeanCount, please check out the main documentation [here](https://github.com/Nef10/SwiftBeanCount).***

## What

This is the importer of SwiftBeanCount. It reads files to create transactions. This library does not include any UI, so consumers need to provide a UI for selecting accounts, settings, as well as editing of transactions.

## How to use

### Import Transactions

1) Create an `Importer` via one of the `new` functions on the `ImporterFactory`, depending on what you want to import.
2) Set your `delegate` on the importer.
3) Call `load()` on the importer.
4) Call `nextTransaction()` to retrive transaction after transactions till it returns `nil`. It is recommended to allow the user the edit the transactions while doing this, as long as `shouldAllowUserToEdit` is true.
5) If the user edits the transaction, and you offer and they accept to save the new mapping, call `saveMapped(description:payee:accountName:)`.
6) Get `balancesToImport()` and `pricesToImport()` from the importer.

### Settings

There are settings for the date tolerance when detecting duplicate transactions, as well as for the mapping the user saved in step 5) of importing transactions. Your app can allow the user to view and edit these via the `Settings` object. Settings are by default stored in `UserDefaults` but you can bring your own `SettingsStorage` by setting `Settings.storage`.

### Help

Each Importer provides a help text. You can access all importers via `ImporterFactory.allImporters`. They each expose an `importerName` and `helpText` on the class.

### More

Please check out the complete documentation [here](https://nef10.github.io/SwiftBeanCountImporter/), or have a look at the [SwiftBeanCountImporterApp](https://github.com/Nef10/SwiftBeanCountImporterApp/) which uses this library.

## Usage

The library supports the Swift Package Manger, so simply add a dependency in your `Package.swift`:

```
.package(url: "https://github.com/Nef10/SwiftBeanCountImporter.git", .exact("X.Y.Z")),
```

*Note: as per semantic versioning all versions changes < 1.0.0 can be breaking, so please use `.exact` for now*
