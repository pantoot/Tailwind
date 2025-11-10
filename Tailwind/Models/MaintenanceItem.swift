import Foundation

struct MaintenanceItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var intervalMiles: Double? // Service interval in miles
    var intervalHours: Double? // Service interval in hours
    var lastServiceMiles: Double
    var lastServiceDate: Date
    var notes: String

    init(id: UUID = UUID(),
         name: String,
         intervalMiles: Double? = nil,
         intervalHours: Double? = nil,
         lastServiceMiles: Double = 0,
         lastServiceDate: Date = Date(),
         notes: String = "") {
        self.id = id
        self.name = name
        self.intervalMiles = intervalMiles
        self.intervalHours = intervalHours
        self.lastServiceMiles = lastServiceMiles
        self.lastServiceDate = lastServiceDate
        self.notes = notes
    }

    // Calculate if service is due based on current mileage
    func isServiceDue(currentMiles: Double) -> Bool {
        guard let interval = intervalMiles else { return false }
        return (currentMiles - lastServiceMiles) >= interval
    }

    // Calculate percentage until next service
    func servicePercentage(currentMiles: Double) -> Double {
        guard let interval = intervalMiles else { return 0 }
        let milesSinceService = currentMiles - lastServiceMiles
        return min(100, (milesSinceService / interval) * 100)
    }

    // Miles until next service
    func milesUntilService(currentMiles: Double) -> Double {
        guard let interval = intervalMiles else { return 0 }
        let remaining = interval - (currentMiles - lastServiceMiles)
        return max(0, remaining)
    }
}

// Preset maintenance schedules for different bike types
struct MaintenanceSchedule {
    static func trekTopFuel() -> [MaintenanceItem] {
        [
            MaintenanceItem(name: "Chain", intervalMiles: 1000, notes: "Replace chain when wear reaches 0.5mm"),
            MaintenanceItem(name: "Cassette", intervalMiles: 2000, notes: "Check for shark tooth wear pattern"),
            MaintenanceItem(name: "Chainring", intervalMiles: 3000, notes: "Replace with cassette if worn"),
            MaintenanceItem(name: "Brake Pads", intervalMiles: 1500, notes: "Check wear indicators"),
            MaintenanceItem(name: "Brake Fluid", intervalMiles: nil, intervalHours: 100, notes: "Bleed hydraulic brakes annually"),
            MaintenanceItem(name: "Suspension Fork Service", intervalMiles: nil, intervalHours: 50, notes: "Lower legs service - clean and regrease"),
            MaintenanceItem(name: "Suspension Fork Rebuild", intervalMiles: nil, intervalHours: 100, notes: "Full fork service with seal replacement"),
            MaintenanceItem(name: "Rear Shock Service", intervalMiles: nil, intervalHours: 50, notes: "Air can service"),
            MaintenanceItem(name: "Rear Shock Rebuild", intervalMiles: nil, intervalHours: 100, notes: "Full shock service"),
            MaintenanceItem(name: "Dropper Post Service", intervalMiles: nil, intervalHours: 100, notes: "Clean and lubricate seals"),
            MaintenanceItem(name: "Pivot Bearings", intervalMiles: 2000, notes: "Check for play, replace if needed"),
            MaintenanceItem(name: "Wheel Bearings", intervalMiles: 2000, notes: "Check for play, regrease or replace"),
            MaintenanceItem(name: "Cables & Housing", intervalMiles: 1500, notes: "Replace if frayed or corroded"),
            MaintenanceItem(name: "Tire Replacement", intervalMiles: 1500, notes: "Check for wear bars and sidewall damage")
        ]
    }

    static func intense951Gravel() -> [MaintenanceItem] {
        [
            // Drivetrain (Shimano GRX)
            MaintenanceItem(name: "Chain Lubrication", intervalMiles: 100, notes: "Clean and lube chain for smooth shifting"),
            MaintenanceItem(name: "Chain Replacement", intervalMiles: 2000, notes: "Replace before 0.5% stretch to protect cassette"),
            MaintenanceItem(name: "Cassette Inspection", intervalMiles: 1500, notes: "Check for wear, shark-fin teeth, or skipping"),
            MaintenanceItem(name: "Chainring Inspection", intervalMiles: 3000, notes: "Check for wear and replace if needed"),
            MaintenanceItem(name: "Derailleur Adjustment", intervalMiles: 500, notes: "Check indexing, limit screws, B-tension"),

            // Brakes (Shimano Hydraulic)
            MaintenanceItem(name: "Brake Pad Inspection", intervalMiles: 500, notes: "Replace if <1mm thickness remaining"),
            MaintenanceItem(name: "Brake Fluid Replacement", intervalMiles: 2000, notes: "Bleed Shimano hydraulic brakes (or yearly)"),
            MaintenanceItem(name: "Rotor Inspection", intervalMiles: 1000, notes: "Check for warping, wear, contamination"),

            // Wheels
            MaintenanceItem(name: "Tire Pressure Check", intervalMiles: 50, notes: "Check and adjust tire pressure"),
            MaintenanceItem(name: "Wheel Truing", intervalMiles: 1000, notes: "Check spoke tension and true if needed"),
            MaintenanceItem(name: "Hub Bearing Service", intervalMiles: 2000, notes: "Clean, grease, and adjust hub bearings"),

            // Frame & Cockpit
            MaintenanceItem(name: "Headset Adjustment", intervalMiles: 1000, notes: "Check for play, adjust preload if needed"),
            MaintenanceItem(name: "Bottom Bracket Service", intervalMiles: 2500, notes: "Check for play, noise, or rough spinning"),
            MaintenanceItem(name: "Frame Inspection", intervalMiles: 500, notes: "Check for cracks, damage on carbon frame"),
            MaintenanceItem(name: "Torque Check", intervalMiles: 300, notes: "Check all critical bolts (stem, seatpost, etc.)")
        ]
    }

    static func pivotTrail429EnduroProX0() -> [MaintenanceItem] {
        [
            // Drivetrain (SRAM X0 Transmission)
            MaintenanceItem(name: "Chain Lubrication", intervalMiles: 100, notes: "Clean and lube SRAM chain"),
            MaintenanceItem(name: "Chain Replacement", intervalMiles: 1500, notes: "MTB chains wear faster - check at 0.5% stretch"),
            MaintenanceItem(name: "Cassette Inspection", intervalMiles: 1200, notes: "Check SRAM Transmission cassette for wear"),
            MaintenanceItem(name: "Derailleur Battery", intervalMiles: nil, intervalHours: 1000, notes: "Replace AXS battery (~2 years typical riding)"),
            MaintenanceItem(name: "Transmission Firmware", intervalMiles: 2000, notes: "Check SRAM AXS app for firmware updates"),

            // Suspension (FOX Factory 36 / Float X)
            MaintenanceItem(name: "Fork Lower Service", intervalMiles: nil, intervalHours: 50, notes: "FOX 36 Factory lower leg service (seals, oil)"),
            MaintenanceItem(name: "Fork Full Service", intervalMiles: nil, intervalHours: 100, notes: "FOX 36 Factory damper service"),
            MaintenanceItem(name: "Shock Service", intervalMiles: nil, intervalHours: 125, notes: "FOX Float X shock full service (or yearly)"),

            // Brakes (SRAM)
            MaintenanceItem(name: "Brake Pad Inspection", intervalMiles: 300, notes: "MTB pads wear faster - check frequently"),
            MaintenanceItem(name: "Brake Bleed", intervalMiles: 1500, notes: "Bleed SRAM brakes (or yearly)"),
            MaintenanceItem(name: "Rotor Inspection", intervalMiles: 800, notes: "Check for warping, minimum thickness (1.5mm)"),

            // Wheels
            MaintenanceItem(name: "Tire Pressure Check", intervalMiles: 30, notes: "Check tubeless sealant and pressure"),
            MaintenanceItem(name: "Tubeless Sealant", intervalMiles: 500, notes: "Refresh tubeless sealant (every 3-6 months)"),
            MaintenanceItem(name: "Wheel Truing", intervalMiles: 800, notes: "Check spoke tension and true wheels"),
            MaintenanceItem(name: "Hub Bearing Service", intervalMiles: 1500, notes: "Clean, grease, and adjust hub bearings"),

            // Frame (Pivot DW-Link with Lifetime Bearing Program)
            MaintenanceItem(name: "Linkage Cleaning", intervalMiles: 200, notes: "Clean dirt buildup around linkage bearings"),
            MaintenanceItem(name: "Frame Inspection", intervalMiles: 500, notes: "Check for damage, cracks, or paint chips"),
            MaintenanceItem(name: "Headset Adjustment", intervalMiles: 800, notes: "Check for play and adjust preload"),
            MaintenanceItem(name: "Bottom Bracket Service", intervalMiles: 2000, notes: "Check for play or noise"),
            MaintenanceItem(name: "Torque Check", intervalMiles: 200, notes: "MTB bolts loosen more - check frequently")
        ]
    }

    static func basic() -> [MaintenanceItem] {
        [
            MaintenanceItem(name: "Chain", intervalMiles: 1000, notes: "Replace chain when wear reaches 0.5mm"),
            MaintenanceItem(name: "Cassette", intervalMiles: 2000, notes: "Check for shark tooth wear pattern"),
            MaintenanceItem(name: "Brake Pads", intervalMiles: 1500, notes: "Check wear indicators"),
            MaintenanceItem(name: "Tire Replacement", intervalMiles: 1500, notes: "Check for wear and damage")
        ]
    }
}
