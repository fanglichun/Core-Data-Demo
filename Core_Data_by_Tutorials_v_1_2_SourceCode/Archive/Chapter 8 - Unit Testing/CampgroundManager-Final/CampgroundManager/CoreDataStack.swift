import Foundation
import CoreData

public class CoreDataStack {

    public init() {
        
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    public var managedObjectModel: NSManagedObjectModel = {
        var modelPath = NSBundle.mainBundle().pathForResource("CampgroundManager", ofType: "momd")
        var modelURL = NSURL.fileURLWithPath(modelPath!)
        var model = NSManagedObjectModel(contentsOfURL: modelURL!)!
        
        return model
    }()

    var applicationDocumentsDirectory: NSURL = {
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1] as! NSURL
    }()

    public lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        NSLog("Providing SQLite persistent store coordinator")
        
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("CampingManager.sqlite")
        var options = [NSInferMappingModelAutomaticallyOption: true, NSMigratePersistentStoresAutomaticallyOption: true]
        var error: NSError? = nil
        
        var psc: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        var ps = psc!.addPersistentStoreWithType(NSSQLiteStoreType, configuration:nil, URL: url, options: options, error: &error)
       
        if (ps == nil) {
            abort()
        }
        
        return psc
    }()
    
    public lazy var rootContext: NSManagedObjectContext? = {
        var context: NSManagedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.persistentStoreCoordinator = self.persistentStoreCoordinator
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return context
    }()
    
    public lazy var mainContext: NSManagedObjectContext? = {
        var mainContext: NSManagedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
        mainContext.parentContext = self.rootContext
        mainContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "mainContextDidSave:", name: NSManagedObjectContextDidSaveNotification, object: mainContext)

        return mainContext
    }()

    public func newDerivedContext() -> NSManagedObjectContext {
        var context: NSManagedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = self.mainContext
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return context
    }

    public func saveContext(context: NSManagedObjectContext) {
        if context.parentContext === self.mainContext {
            saveDerivedContext(context)
            return
        }
        
        context.performBlock() {
            var error: NSError? = nil
            if !(context.obtainPermanentIDsForObjects(Array(context.insertedObjects), error: &error)) {
                NSLog("Error obtaining permanent IDs for \(context.insertedObjects), \(error)")
            }

            if !(context.save(&error)) {
                NSLog("Unresolved core data error: \(error)")
                abort()
            }
        }
    }
    
    public func saveDerivedContext(context: NSManagedObjectContext) {
        context.performBlock() {
            var error: NSError? = nil
            if !(context.obtainPermanentIDsForObjects(Array(context.insertedObjects), error: &error)) {
                NSLog("Error obtaining permanent IDs for \(context.insertedObjects), \(error)")
            }

            if !(context.save(&error)) {
                NSLog("Unresolved core data error: \(error)")
                abort()
            }

            self.saveContext(self.mainContext!)
        }
    }

    @objc func mainContextDidSave(notification: NSNotification) {
        self.saveContext(self.rootContext!)
    }
    
}