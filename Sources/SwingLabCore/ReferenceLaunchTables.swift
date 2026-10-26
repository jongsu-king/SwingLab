import Foundation

extension ReferenceLaunchData {
    public static let sources: [ReferenceSource] = [
        .init(id: "trackman.pga.2023", title: "TrackMan PGA Tour averages — 2023, published May 2024",
              url: URL(string: "https://a.storyblok.com/f/117513/1920x883/6aefae601d/pga_tour-averages_trackman_blog.jpg")!,
              publicationYear: 2024, dataYear: 2023),
        .init(id: "trackman.lpga.2023", title: "TrackMan LPGA Tour averages — 2023, published May 2024",
              url: URL(string: "https://a.storyblok.com/f/117513/1920x883/9617e89ecd/lpga_tour-averages_trackman_blog.jpg")!,
              publicationYear: 2024, dataYear: 2023),
        .init(id: "trackman.pga.older", title: "TrackMan PGA Tour averages — older undated table",
              url: URL(string: "https://support.trackmangolf.com/hc/en-us/article_attachments/7349802113051")!,
              publicationYear: nil, dataYear: nil),
        .init(id: "trackman.lpga.older", title: "TrackMan LPGA Tour averages — older undated table",
              url: URL(string: "https://support.trackmangolf.com/hc/en-us/article_attachments/7349801987483")!,
              publicationYear: nil, dataYear: nil),
        .init(id: "usga.r22-01", title: "USGA / R&A R22-01 — Launch conditions, May 2019",
              url: URL(string: "https://www.usga.org/content/dam/usga/pdf/Equipment/R22-01%20Launch%20conditions%20of%20male%20and%20female%20golfers%20of%20different%20skill%20levels.pdf")!,
              publicationYear: 2019, dataYear: nil),
        .init(id: "usga.di.2023", title: "USGA — Golfer Performance Measurement, December 2023 update",
              url: URL(string: "https://www.usga.org/content/dam/usga/images/course-care/GolferExperience/DI_Golfer_Performance_Measurement%202023%20Update.pdf")!,
              publicationYear: 2023, dataYear: nil)
    ]

    public static let rows: [ReferenceLaunchRow] = tourRows + usgaRows + surfaceRows

    /// Numeric facts transcribed from the publisher's original tables; no images/marketing
    /// text are bundled. Original units and rounding are retained before SI conversion.
    /// Column order: club speed mph, ball speed mph, smash, launch deg, spin rpm, carry yd, apex yd.
    private static let tourRows: [ReferenceLaunchRow] = {
        let pga: [(ReferenceClub, [Double])] = [
            (.driver, [115,171,1.49,10.4,2545,282,35]),
            (.wood3, [110,162,1.47,9.3,3663,249,32]),
            (.wood5, [106,156,1.47,9.7,4322,236,33]),
            (.hybrid, [102,149,1.47,10.2,4587,231,31]),
            (.iron3, [100,145,1.46,10.3,4404,218,30]),
            (.iron4, [98,140,1.44,10.8,4782,209,31]),
            (.iron5, [96,135,1.41,11.9,5280,199,33]),
            (.iron6, [94,130,1.39,14.0,6204,188,32]),
            (.iron7, [92,123,1.34,16.1,7124,176,34]),
            (.iron8, [89,118,1.33,17.8,8078,164,33]),
            (.iron9, [87,112,1.29,20.0,8793,152,32]),
            (.pitchingWedge, [84,104,1.24,23.7,9316,142,32])
        ]
        let lpga: [(ReferenceClub, [Double])] = [
            (.driver, [96,143,1.49,12.6,2506,223,26]),
            (.wood3, [92,135,1.47,11.6,2595,200,25]),
            (.wood5, [90,130,1.46,12.3,4320,189,25]),
            (.hybrid, [87,125,1.44,13.9,4504,178,25]),
            (.iron4, [82,118,1.43,13.9,4608,175,25]),
            (.iron5, [81,114,1.42,14.6,4966,166,25]),
            (.iron6, [80,111,1.41,16.7,5904,155,25]),
            (.iron7, [78,106,1.38,18.5,6630,143,26]),
            (.iron8, [76,102,1.36,20.8,7413,133,27]),
            (.iron9, [74,95,1.30,23.5,7605,123,27]),
            (.pitchingWedge, [72,88,1.25,25.2,8465,111,27])
        ]
        let older: [(ReferenceClub, [Double])] = [
            (.driver, [113,167,1.48,10.9,2686,275,32]),
            (.wood3, [107,158,1.48,9.2,3655,243,30]),
            (.wood5, [103,152,1.47,9.4,4350,230,31]),
            (.hybrid, [100,146,1.46,10.2,4437,225,29]),
            (.iron3, [98,142,1.45,10.4,4630,212,27]),
            (.iron4, [96,137,1.43,11.0,4836,203,28]),
            (.iron5, [94,132,1.41,12.1,5361,194,31]),
            (.iron6, [92,127,1.38,14.1,6231,183,30]),
            (.iron7, [90,120,1.33,16.3,7097,172,32]),
            (.iron8, [87,115,1.32,18.1,7998,160,31]),
            (.iron9, [85,109,1.28,20.4,8647,148,30]),
            (.pitchingWedge, [83,102,1.23,24.2,9304,136,29])
        ]
        // Visually checked on PDF page 2: its hidden text layer also contains old PGA
        // text and must not be used to infer LPGA rows or overwrite these visible values.
        let lpgaOlder: [(ReferenceClub, [Double])] = [
            (.driver, [94,140,1.48,13.2,2611,218,25]),
            (.wood3, [90,132,1.48,11.2,2704,195,23]),
            (.wood5, [88,128,1.47,12.1,4501,185,26]),
            (.wood7, [85,123,1.46,12.7,4693,174,25]),
            (.iron4, [80,116,1.45,14.3,4801,169,24]),
            (.iron5, [79,112,1.43,14.8,5081,161,23]),
            (.iron6, [78,109,1.41,17.1,5943,152,25]),
            (.iron7, [76,104,1.38,19.0,6699,141,26]),
            (.iron8, [74,100,1.33,20.8,7494,130,25]),
            (.iron9, [72,93,1.32,23.9,7589,119,26]),
            (.pitchingWedge, [70,86,1.28,25.7,8403,107,23])
        ]
        return tour(pga, population: .pga2023, sourceID: "trackman.pga.2023")
            + tour(lpga, population: .lpga2023, sourceID: "trackman.lpga.2023")
            + tour(older, population: .pgaOlder, sourceID: "trackman.pga.older")
            + tour(lpgaOlder, population: .lpgaOlder, sourceID: "trackman.lpga.older")
    }()

    private static func tour(_ table: [(ReferenceClub, [Double])], population: ReferencePopulation,
                             sourceID: String) -> [ReferenceLaunchRow] {
        table.map { club, numbers in
            let metrics: [ReferenceMetric] = [.clubSpeed,.ballSpeed,.smashFactor,.launch,.spin,.carry,.apex]
            let units: [ReferenceUnit] = [.mph,.mph,.ratio,.degrees,.rpm,.yards,.yards]
            let values = Dictionary(uniqueKeysWithValues: zip(metrics.indices, metrics).map { index, metric in
                (metric, published(numbers[index], unit: units[index], sourceID: sourceID,
                                   locator: "\(club.rawValue), \(metric.rawValue); yards table"))
            })
            return ReferenceLaunchRow(id: "\(sourceID).\(club.rawValue)", club: club,
                population: population, skillGroup: nil, sampleCount: nil, values: values)
        }
    }

    /// R22-01 tables 5, 6, 7, pp. 5–7. Groups are in printed order (professional, then 1…4).
    /// Column order: club speed, ball speed, efficiency, launch, spin, carry, apex.
    /// Each column contains the published mean followed by its published SD. Nil = unreported.
    private static let usgaRows: [ReferenceLaunchRow] = {
        let femaleIron: [[Double?]] = [
            [79.6,3.4,112.9,5.7,1.40,0.1,15.1,1.8,5217,678,155.5,12.1,23.7,3.3],
            [74.7,4.1,102.8,8.2,1.37,0.1,14.2,2.9,4685,955,132.0,23.4,16.9,5.6],
            [64.7,11.1,90.5,15.1,1.36,0.1,15.1,3.2,4096,1252,106.7,32.7,12.9,8.8],
            [56.5,4.6,77.6,9.5,1.33,0.1,13.7,5.2,3712,1230,75.1,29.3,7.2,4.8],
            [52.6,7.2,71.2,13.5,1.29,0.2,14.3,4.9,3460,1565,64.5,32.5,6.0,4.7]
        ]
        let femaleDriver: [[Double?]] = [
            [93.8,3.8,127.6,11.3,1.44,0.1,14.3,2.7,2872,910,216.7,13.3,27.4,3.1],
            [86.3,5.7,122.2,10.6,1.43,0.1,14.1,2.9,3067,1057,173.6,25.4,18.9,7.2],
            [77.0,6.5,109.6,9.8,1.44,0.1,13.2,4.6,2784,983,135.8,25.9,13.3,6.1],
            [68.4,5.2,97.0,9.1,1.41,0.1,11.3,3.9,2671,909,100.1,29.3,7.7,4.8],
            [62.6,8.5,86.8,13.9,1.39,0.1,10.4,5.1,3095,1392,76.5,37.5,5.6,5.2]
        ]
        let maleIron: [[Double?]] = [
            [89.4,5.4,125.0,9.2,1.39,0.1,12.8,2.4,6097,645,176.4,18.1,25.1,6.1],
            [85.7,5.6,120.2,9.9,1.38,0.1,12.4,3.0,5171,925,164.4,23.1,23.3,6.4],
            [81.0,8.1,112.2,13.2,1.37,0.1,12.1,4.0,4835,1191,145.5,31.5,18.9,7.9],
            [77.4,9.1,105.9,15.0,1.33,0.1,12.5,4.7,4354,1333,129.9,39.3,16.2,8.1],
            [78.5,8.9,103.8,19.2,1.30,0.2,11.7,5.1,4942,1492,119.2,47.6,14.8,9.8]
        ]
        let maleDriver: [[Double?]] = [
            [113.7,4.6,169.0,6.6,1.49,0.0,11.1,2.3,2259,1120,262.2,66.9,nil,nil],
            [100.5,6.8,143.8,9.9,1.43,0.0,11.4,2.8,3274,780,215.1,23.4,27.8,8.5],
            [91.4,9.2,130.6,13.1,1.43,0.1,10.7,3.6,3313,1140,183.6,34.5,21.1,8.8],
            [85.8,9.5,121.9,15.3,1.42,0.1,12.2,4.9,3202,1250,163.3,33.6,16.3,8.0],
            [89.6,9.9,125.6,16.6,1.39,0.1,10.2,4.8,3839,1309,163.1,49.7,17.6,11.1]
        ]
        return usga(femaleIron, counts: [221,108,148,183,237], club: .iron6, population: .usgaFemale)
            + usga(femaleDriver, counts: [528,364,236,243,296], club: .driver, population: .usgaFemale)
            + usga(maleIron, counts: [142,1341,1010,321,196], club: .iron6, population: .usgaMale)
            + usga(maleDriver, counts: [12334,433,400,164,101], club: .driver, population: .usgaMale)
    }()

    private static func usga(_ table: [[Double?]], counts: [Int], club: ReferenceClub,
                             population: ReferencePopulation) -> [ReferenceLaunchRow] {
        let metrics: [ReferenceMetric] = [.clubSpeed,.ballSpeed,.smashFactor,.launch,.spin,.carry,.apex]
        let units: [ReferenceUnit] = [.mph,.mph,.ratio,.degrees,.rpm,.yards,.yards]
        return table.enumerated().map { group, numbers in
            var values: [ReferenceMetric: PublishedLaunchValue] = [:]
            for index in metrics.indices {
                guard let mean = numbers[index * 2] else { continue }
                let page = index == 0 ? 5 : (index >= 5 ? 7 : 6)
                values[metrics[index]] = published(mean, unit: units[index], sourceID: "usga.r22-01",
                    locator: "Table \(page), page \(page), \(population.rawValue), \(club.rawValue), group \(group), \(metrics[index].rawValue)",
                    sd: numbers[index * 2 + 1])
            }
            return ReferenceLaunchRow(id: "usga.r22-01.\(population.rawValue).\(club.rawValue).\(group)",
                club: club, population: population, skillGroup: group, sampleCount: counts[group], values: values)
        }
    }

    /// DI2023 p.7 states these averages. No regression slope is substituted for a mean,
    /// and the report's total hitting distances are not mislabeled as carry.
    private static let surfaceRows: [ReferenceLaunchRow] = [
        surface(.iron7, .recreationalGrass, 1.33, figure: 8),
        surface(.iron7, .recreationalMat, 1.41, figure: 8),
        surface(.pitchingWedge, .recreationalGrass, 1.18, figure: 9),
        surface(.pitchingWedge, .recreationalMat, 1.21, figure: 9)
    ]

    private static func surface(_ club: ReferenceClub, _ population: ReferencePopulation,
                                _ smash: Double, figure: Int) -> ReferenceLaunchRow {
        ReferenceLaunchRow(id: "usga.di.2023.\(population.rawValue).\(club.rawValue)", club: club,
            population: population, skillGroup: nil, sampleCount: nil,
            values: [.smashFactor: published(smash, unit: .ratio, sourceID: "usga.di.2023",
                locator: "Page 7, prose accompanying Figure \(figure), \(population.rawValue)")])
    }

    private static func published(_ value: Double, unit: ReferenceUnit, sourceID: String,
                                  locator: String, sd: Double? = nil) -> PublishedLaunchValue {
        let source = sources.first { $0.id == sourceID }!
        return PublishedLaunchValue(publishedValue: value, publishedUnit: unit,
            publishedStandardDeviation: sd, citation: ReferenceCitation(sourceID: sourceID, locator: locator,
                publicationYear: source.publicationYear, dataYear: source.dataYear))
    }
}
