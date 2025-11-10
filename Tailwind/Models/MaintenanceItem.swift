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
            // Drivetrain (Shimano GRX 2x)
            MaintenanceItem(name: "Chain Lubrication", intervalMiles: 100, notes: "Clean and lube chain - gravel conditions require frequent cleaning"),
            MaintenanceItem(name: "Chain Replacement", intervalMiles: 2000, notes: "Use chain checker - replace at 0.5% stretch to protect cassette"),
            MaintenanceItem(name: "Cassette Inspection", intervalMiles: 1500, notes: "11-34T GRX cassette - check for shark-fin teeth, skipping under load"),
            MaintenanceItem(name: "Chainring Inspection (Both)", intervalMiles: 3000, notes: "2x chainrings (48/32 or similar) - check both for wear"),
            MaintenanceItem(name: "Front Derailleur Adjustment", intervalMiles: 500, notes: "Check trim positions, cable tension, limit screws"),
            MaintenanceItem(name: "Rear Derailleur Adjustment", intervalMiles: 500, notes: "GRX shadow design - check B-tension, indexing, hanger alignment"),
            MaintenanceItem(name: "Derailleur Hanger Check", intervalMiles: 1000, notes: "Carbon frame - ensure hanger isn't bent from crashes/transport"),

            // Brakes (Shimano GRX Hydraulic Disc)
            MaintenanceItem(name: "Brake Pad Inspection", intervalMiles: 500, notes: "Check both wheels - replace pads if <1mm material remaining"),
            MaintenanceItem(name: "Brake Fluid Bleed", intervalMiles: 2000, notes: "Shimano mineral oil - bleed yearly or when lever feels spongy"),
            MaintenanceItem(name: "Rotor Inspection", intervalMiles: 1000, notes: "160mm rotors - check for warping, minimum 1.5mm thickness"),
            MaintenanceItem(name: "Brake Caliper Alignment", intervalMiles: 500, notes: "Check for rub, recenter if needed after wheel removal"),

            // Wheels & Tires
            MaintenanceItem(name: "Tire Pressure Check", intervalMiles: 50, notes: "700x40c gravel tires - 40-60psi depending on terrain"),
            MaintenanceItem(name: "Tire Tread Inspection", intervalMiles: 500, notes: "Check for cuts, sidewall damage, tread wear"),
            MaintenanceItem(name: "Tire Rotation", intervalMiles: 1000, notes: "Swap front/rear to even wear (if identical tires)"),
            MaintenanceItem(name: "Wheel Truing", intervalMiles: 1000, notes: "Check spoke tension, true wheels if wobbling"),
            MaintenanceItem(name: "Spoke Tension Check", intervalMiles: 1500, notes: "Gravel riding loosens spokes - check and adjust"),
            MaintenanceItem(name: "Hub Bearing Service", intervalMiles: 2000, notes: "Clean, regrease, adjust preload - critical for smooth rolling"),
            MaintenanceItem(name: "Thru-Axle Inspection", intervalMiles: 500, notes: "Check threads, apply light grease to prevent seizing"),

            // Frame & Cockpit (Carbon Frame)
            MaintenanceItem(name: "Frame Cleaning & Inspection", intervalMiles: 200, notes: "Clean mud/grit, inspect carbon for cracks especially BB, dropouts"),
            MaintenanceItem(name: "Headset Adjustment", intervalMiles: 1000, notes: "Check for play or binding, adjust preload"),
            MaintenanceItem(name: "Headset Bearing Inspection", intervalMiles: 2000, notes: "Integrated carbon headset - check bearings for roughness"),
            MaintenanceItem(name: "Bottom Bracket Service", intervalMiles: 2500, notes: "Press-fit or threaded BB - check for play, creaking, rough spinning"),
            MaintenanceItem(name: "Seatpost Inspection", intervalMiles: 1000, notes: "Carbon seatpost - check for slipping, proper torque (4-6 Nm)"),
            MaintenanceItem(name: "Handlebar & Stem Torque", intervalMiles: 500, notes: "Carbon bar/stem - verify proper torque (5-6 Nm typically)"),
            MaintenanceItem(name: "Cable Housing Inspection", intervalMiles: 1500, notes: "Check for fraying, kinks, replace if shifting/braking feels sticky"),

            // Finishing Kit
            MaintenanceItem(name: "Bar Tape Replacement", intervalMiles: 1500, notes: "Replace when worn, torn, or uncomfortable"),
            MaintenanceItem(name: "Saddle Inspection", intervalMiles: 1000, notes: "Check rails, cover for wear or damage"),
            MaintenanceItem(name: "Pedal Bearing Service", intervalMiles: 2000, notes: "If clipless pedals - service bearings, check cleat wear"),

            // General Maintenance
            MaintenanceItem(name: "Full Bike Wash", intervalMiles: 100, notes: "After gravel rides - remove grit that causes premature wear"),
            MaintenanceItem(name: "Bolt Check (Critical)", intervalMiles: 300, notes: "Stem, seatpost clamp, crank bolts, chainring bolts, bottle cages"),
            MaintenanceItem(name: "Professional Tune-Up", intervalMiles: 3000, notes: "Comprehensive service at bike shop")
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
