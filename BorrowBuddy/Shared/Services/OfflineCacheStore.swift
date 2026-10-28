import CoreData
import Foundation

struct CachedAccount: Codable, Equatable {
    var displayName: String
    var neighborhood: String
    var phoneNumber: String
    var creditBalance: Int
    var creditHeld: Int
    var streetAddress: String
    var unit: String
    var postalCode: String
    var latitude: Double?
    var longitude: Double?
    var identityVerified: Bool
    var addressConfirmed: Bool
    var isPro: Bool

    init(_ account: AccountSummary) {
        displayName = account.displayName
        neighborhood = account.neighborhood
        phoneNumber = account.phoneNumber
        creditBalance = account.creditBalance
        creditHeld = account.creditHeld
        streetAddress = account.streetAddress
        unit = account.unit
        postalCode = account.postalCode
        latitude = account.latitude
        longitude = account.longitude
        identityVerified = account.identityVerified
        addressConfirmed = account.addressConfirmed
        isPro = account.isPro
    }

    var account: AccountSummary {
        AccountSummary(
            displayName: displayName,
            neighborhood: neighborhood,
            phoneNumber: phoneNumber,
            creditBalance: creditBalance,
            creditHeld: creditHeld,
            latitude: latitude,
            longitude: longitude,
            streetAddress: streetAddress,
            unit: unit,
            postalCode: postalCode,
            identityVerified: identityVerified,
            addressConfirmed: addressConfirmed,
            isPro: isPro
        )
    }
}

struct CachedTool: Codable, Equatable {
    var id: String
    var ownerID: String
    var ownerName: String
    var name: String
    var category: String
    var condition: String
    var details: String
    var dailyCredits: Int
    var depositCredits: Int
    var latitude: Double
    var longitude: Double
    var pickupAddress: String
    var isHighValue: Bool
    var estimatedValue: Int
    var listingStatus: String

    init(_ tool: BorrowingTool) {
        id = tool.id
        ownerID = tool.ownerID
        ownerName = tool.ownerName
        name = tool.name
        category = tool.category
        condition = tool.condition
        details = tool.details
        dailyCredits = tool.dailyCredits
        depositCredits = tool.depositCredits
        latitude = tool.latitude
        longitude = tool.longitude
        pickupAddress = tool.pickupAddress
        isHighValue = tool.isHighValue
        estimatedValue = tool.estimatedValue
        listingStatus = tool.listingStatus
    }

    var tool: BorrowingTool {
        BorrowingTool(
            id: id,
            ownerID: ownerID,
            ownerName: ownerName,
            ownerRating: 0,
            ownerLoanCount: 0,
            name: name,
            category: category,
            condition: condition,
            details: details,
            dailyCredits: dailyCredits,
            depositCredits: depositCredits,
            latitude: latitude,
            longitude: longitude,
            pickupAddress: pickupAddress,
            imageURL: nil,
            isHighValue: isHighValue,
            estimatedValue: estimatedValue,
            photoData: nil,
            listingStatus: listingStatus
        )
    }
}

struct CachedLoan: Codable, Equatable {
    var id: String
    var receipt: String
    var toolID: String
    var toolName: String
    var ownerID: String
    var borrowerID: String
    var pickupAt: Date
    var returnAt: Date
    var totalHold: Int
    var status: String
    var requestedAt: Date
    var pickupAddress: String
    var ownerName: String
    var borrowerName: String
    var rentalCredits: Int
    var serviceCredits: Int
    var depositCredits: Int
    var latitude: Double
    var longitude: Double
    var lifecycleStage: String

    init(_ loan: ReservationRecord) {
        id = loan.id
        receipt = loan.receipt
        toolID = loan.toolID
        toolName = loan.toolName
        ownerID = loan.ownerID
        borrowerID = loan.borrowerID
        pickupAt = loan.pickupAt
        returnAt = loan.returnAt
        totalHold = loan.totalHold
        status = loan.status.rawValue
        requestedAt = loan.requestedAt
        pickupAddress = loan.pickupAddress
        ownerName = loan.ownerName
        borrowerName = loan.borrowerName
        rentalCredits = loan.rentalCredits
        serviceCredits = loan.serviceCredits
        depositCredits = loan.depositCredits
        latitude = loan.toolSnapshot.latitude
        longitude = loan.toolSnapshot.longitude
        lifecycleStage = loan.lifecycleStage.rawValue
    }

    var loan: ReservationRecord {
        ReservationRecord(
            id: id,
            receipt: receipt,
            toolID: toolID,
            toolName: toolName,
            ownerID: ownerID,
            borrowerID: borrowerID,
            pickupAt: pickupAt,
            returnAt: returnAt,
            totalHold: totalHold,
            status: ReservationStatus(rawValue: status) ?? .pending,
            requestedAt: requestedAt,
            lifecycleStage: LoanLifecycleStage(rawValue: lifecycleStage) ?? .pending,
            pickupAddress: pickupAddress,
            ownerName: ownerName,
            borrowerName: borrowerName,
            rentalCredits: rentalCredits,
            serviceCredits: serviceCredits,
            depositCredits: depositCredits,
            toolSnapshot: BorrowingTool(
                id: toolID,
                ownerID: ownerID,
                ownerName: ownerName,
                ownerRating: 0,
                ownerLoanCount: 0,
                name: toolName,
                category: "",
                condition: "",
                details: "",
                dailyCredits: 0,
                depositCredits: depositCredits,
                latitude: latitude,
                longitude: longitude,
                pickupAddress: pickupAddress,
                imageURL: nil,
                isHighValue: false,
                estimatedValue: 0,
                photoData: nil,
                listingStatus: "reserved"
            )
        )
    }
}

final class OfflineCacheStore {
    private let context: NSManagedObjectContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(inMemory: Bool = false) {
        let model = OfflineCacheStore.makeModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let description: [String: Any]
        if inMemory {
            description = [NSMigratePersistentStoresAutomaticallyOption: true]
            try? coordinator.addPersistentStore(
                ofType: NSInMemoryStoreType,
                configurationName: nil,
                at: nil,
                options: description
            )
        } else {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("BorrowBuddyOffline.sqlite")
            try? coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: url,
                options: [
                    NSMigratePersistentStoresAutomaticallyOption: true,
                    NSInferMappingModelAutomaticallyOption: true
                ]
            )
        }
        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
    }

    func saveAccount(_ account: AccountSummary) {
        save(CachedAccount(account), key: "account")
    }

    func loadAccount() -> AccountSummary? {
        load(CachedAccount.self, key: "account")?.account
    }

    func saveTools(_ tools: [BorrowingTool]) {
        save(tools.map(CachedTool.init), key: "tools")
    }

    func loadTools() -> [BorrowingTool] {
        load([CachedTool].self, key: "tools")?.map(\.tool) ?? []
    }

    func saveLoans(_ loans: [ReservationRecord]) {
        save(loans.map(CachedLoan.init), key: "loans")
    }

    func loadLoans() -> [ReservationRecord] {
        load([CachedLoan].self, key: "loans")?.map(\.loan) ?? []
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let payload = try? encoder.encode(value) else { return }
        let request = NSFetchRequest<NSManagedObject>(entityName: "CachedRecord")
        request.predicate = NSPredicate(format: "cacheKey == %@", key)
        let entity = context.persistentStoreCoordinator?.managedObjectModel.entitiesByName["CachedRecord"]
        guard let entity else { return }
        let object = (try? context.fetch(request))?.first ?? NSManagedObject(entity: entity, insertInto: context)
        object.setValue(key, forKey: "cacheKey")
        object.setValue(payload, forKey: "payload")
        object.setValue(Date(), forKey: "updatedAt")
        try? context.save()
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CachedRecord")
        request.predicate = NSPredicate(format: "cacheKey == %@", key)
        request.fetchLimit = 1
        guard let payload = (try? context.fetch(request))?.first?.value(forKey: "payload") as? Data else {
            return nil
        }
        return try? decoder.decode(type, from: payload)
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "CachedRecord"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let key = NSAttributeDescription()
        key.name = "cacheKey"
        key.attributeType = .stringAttributeType
        key.isOptional = false

        let payload = NSAttributeDescription()
        payload.name = "payload"
        payload.attributeType = .binaryDataAttributeType
        payload.isOptional = false

        let updatedAt = NSAttributeDescription()
        updatedAt.name = "updatedAt"
        updatedAt.attributeType = .dateAttributeType
        updatedAt.isOptional = true

        entity.properties = [key, payload, updatedAt]
        model.entities = [entity]
        return model
    }
}
