import Foundation
import SwingLabCore

enum CatalogStore {
    static let catalog: EquipmentCatalog = {
        guard let url = Bundle.main.url(forResource: "equipment-catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(EquipmentCatalog.self, from: data) else { return .init() }
        return catalog
    }()
}
