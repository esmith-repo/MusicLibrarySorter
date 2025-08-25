//
//  main.swift
//  MusicLibrarySorter
//
//  Created by Eric Smith on 8/25/25.
//

import Foundation

// MARK: - Track Struct
struct Track {
    let title: String
    let artist: String
    let year: Int
}

// MARK: - Music XML Parser
class MusicLibraryParser: NSObject, XMLParserDelegate {
    private var tracks: [Track] = []
    
    private var currentKey: String = ""
    private var currentValue: String = ""
    
    private var tempTrack: [String: String] = [:]
    
    private var insideTracksDict = false
    private var currentParentKey: String = ""
    
    func parse(xmlURL: URL) -> [Track] {
        if let parser = XMLParser(contentsOf: xmlURL) {
            parser.delegate = self
            parser.parse()
        }
        return tracks
    }
    
    // MARK: - XMLParserDelegate
    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        currentValue = ""
        
        // Detect entering a <dict> inside <key>Tracks</key>
        if elementName == "dict" && currentParentKey == "Tracks" {
            tempTrack = [:]
            insideTracksDict = true
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            currentValue += trimmed
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        
        if elementName == "key" {
            currentKey = currentValue
            // Detect the main Tracks key
            if currentKey == "Tracks" {
                currentParentKey = "Tracks"
            }
        } else if (elementName == "string" || elementName == "integer") && insideTracksDict {
            tempTrack[currentKey] = currentValue
        } else if elementName == "dict" && insideTracksDict {
            // Finished one track dict
            if let name = tempTrack["Name"], let artist = tempTrack["Artist"] {
                let year = Int(tempTrack["Year"] ?? "") ?? 0
                tracks.append(Track(title: name, artist: artist, year: year))
            }
            tempTrack = [:]
            insideTracksDict = false
        }
    }
}

// MARK: - Group Tracks by Decade
func groupTracksByDecade(_ tracks: [Track]) -> [String: [Track]] {
    var decades: [String: [Track]] = [:]
    for track in tracks where track.year > 0 {
        let decadeStart = (track.year / 10) * 10
        let decadeLabel = "\(decadeStart)s"
        decades[decadeLabel, default: []].append(track)
    }
    return decades
}

// MARK: - Main Program
print("Starting Music Library Sorter...")

// Update this path to your exported Music Library.xml
let xmlPath = "/Users/ericsmith/Documents/Library.xml"
let xmlURL = URL(fileURLWithPath: xmlPath)

let parser = MusicLibraryParser()
let tracks = parser.parse(xmlURL: xmlURL)
print("✅ Fetched \(tracks.count) tracks from XML.")

let decades = groupTracksByDecade(tracks)
print("✅ Sorted tracks by decade.")

// Create CSV output file in Documents
let fileManager = FileManager.default
let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
let outputFileURL = documentsURL.appendingPathComponent("SortedMusicByDecade.csv")

// CSV Header
var csvString = "Title,Artist,Year,Decade\n"

for decade in decades.keys.sorted() {
    for track in decades[decade]! {
        // Escape quotes and commas in text fields
        let title = "\"\(track.title.replacingOccurrences(of: "\"", with: "\"\""))\""
        let artist = "\"\(track.artist.replacingOccurrences(of: "\"", with: "\"\""))\""
        let year = "\(track.year)"
        let decadeLabel = decade
        csvString += "\(title),\(artist),\(year),\(decadeLabel)\n"
    }
}

do {
    try csvString.write(to: outputFileURL, atomically: true, encoding: .utf8)
    print("✅ Sorted music saved to CSV: \(outputFileURL.path)")
} catch {
    print("❌ Failed to write CSV file: \(error)")
}
