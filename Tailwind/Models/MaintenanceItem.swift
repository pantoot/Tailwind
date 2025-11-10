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

    static func intenseGravel() -> [MaintenanceItem] {
        [
            MaintenanceItem(name: "Chain", intervalMiles: 1000, notes: "Replace chain when wear reaches 0.5mm"),
            MaintenanceItem(name: "Cassette", intervalMiles: 2000, notes: "Check for shark tooth wear pattern"),
            MaintenanceItem(name: "Chainrings (2x)", intervalMiles: 3000, notes: "Replace when teeth show wear"),
            MaintenanceItem(name: "Brake Pads", intervalMiles: 2000, notes: "Check wear indicators"),
            MaintenanceItem(name: "Brake Fluid", intervalMiles: nil, intervalHours: 100, notes: "Bleed hydraulic brakes annually"),
            MaintenanceItem(name: "Cables & Housing", intervalMiles: 1500, notes: "Replace if frayed or corroded"),
            MaintenanceItem(name: "Bottom Bracket", intervalMiles: 3000, notes: "Check for play or noise"),
            MaintenanceItem(name: "Headset Bearings", intervalMiles: 2000, notes: "Check for play, regrease if needed"),
            MaintenanceItem(name: "Wheel Bearings", intervalMiles: 2000, notes: "Check for play, regrease or replace"),
            MaintenanceItem(name: "Bar Tape", intervalMiles: 1000, notes: "Replace when worn or damaged"),
            MaintenanceItem(name: "Tire Replacement", intervalMiles: 2000, notes: "Gravel tires - check tread depth")
        ]
    }

    static func pivotTrail429() -> [MaintenanceItem] {
        [
            MaintenanceItem(name: "Transmission Chain", intervalMiles: 1500, notes: "SRAM Transmission - check wear at 0.8%"),
            MaintenanceItem(name: "Transmission Cassette", intervalMiles: 3000, notes: "SRAM T-Type cassette"),
            MaintenanceItem(name: "Chainring", intervalMiles: 3000, notes: "SRAM Transmission chainring"),
            MaintenanceItem(name: "Brake Pads", intervalMiles: 1500, notes: "Check wear indicators"),
            MaintenanceItem(name: "Brake Fluid", intervalMiles: nil, intervalHours: 100, notes: "Bleed hydraulic brakes annually"),
            MaintenanceItem(name: "Suspension Fork Service", intervalMiles: nil, intervalHours: 50, notes: "Lower legs service - clean and regrease"),
            MaintenanceItem(name: "Suspension Fork Rebuild", intervalMiles: nil, intervalHours: 100, notes: "Full fork service with seal replacement"),
            MaintenanceItem(name: "Rear Shock Service", intervalMiles: nil, intervalHours: 50, notes: "Air can service"),
            MaintenanceItem(name: "Rear Shock Rebuild", intervalMiles: nil, intervalHours: 100, notes: "Full shock service"),
            MaintenanceItem(name: "Dropper Post Service", intervalMiles: nil, intervalHours: 100, notes: "Clean and lubricate seals"),
            MaintenanceItem(name: "DW-Link Pivot Bearings", intervalMiles: 2000, notes: "Pivot-specific DW-Link bearings"),
            MaintenanceItem(name: "Carbon Wheel Inspection", intervalMiles: 1000, notes: "Check for cracks, spoke tension"),
            MaintenanceItem(name: "Hub Bearings", intervalMiles: 1500, notes: "Carbon wheels - check/service regularly"),
            MaintenanceItem(name: "AXS Battery", intervalMiles: nil, notes: "Charge every 20 hours of riding"),
            MaintenanceItem(name: "AXS Firmware Update", intervalMiles: nil, notes: "Check for updates monthly"),
            MaintenanceItem(name: "Tire Replacement", intervalMiles: 1200, notes: "MTB tires - check knob wear")
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
