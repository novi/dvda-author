//
//  Author.swift
//  dvda-author-mac
//
//  Created by Yusuke Ito on 7/22/24.
//

import Foundation

enum AuthorError: Error {
    case unsupportedFileType(UInt8, URL)
    case unsupportedBitDepthOrSampleRate(URL)
}

class Author {
    
    struct Group {
        let files: [URL]
    }
    
    let outputDir: URL
    let audioTsDir: UnsafeMutablePointer<CChar>
    let audioTsDirURL: URL
    init(outputDir: URL) {
        self.outputDir = outputDir
        self.audioTsDirURL = outputDir.appending(path: "AUDIO_TS")
        self.audioTsDir = self.audioTsDirURL.path(percentEncoded: false).copyCString()
    }
    
    func build(groups: [Group]) throws {
        
        try FileManager.default.createDirectory(at: audioTsDirURL, withIntermediateDirectories: true)
        
        let numOfGroups = UInt8(groups.count)
        precondition(groups.count <= 9)
        
        
        // clean and create work directory
        let tempDir = FileManager.default.temporaryDirectory
        print(tempDir)
        
        
        // init variable
        let img0 = UnsafeMutablePointer<pic>.allocate(capacity: 1)
        img0.initialize(repeating: pic(), count: 1)
        memset(img0, 0, MemoryLayout<pic>.size)
        
        var globalData = globalData()
        var command = command_t()
        defer {
//            free_memory(&command, &globalData)
        }
        globalData.topmenu = Int8(NO_MENU)
        globalData.veryverbose = true
        globalData.debugging = true
        globalData.settings.workdir = tempDir.path(percentEncoded: false).copyCString()
        globalData.settings.tempdir = tempDir.path(percentEncoded: false).copyCString()
        globalData.fixwav_suffix = "_fix_".copyCString()
        globalData.fixwav_enable = true
        globalData.fixwav_virtual_enable = true
        globalData.fixwav_automatic = true
        // set dummy path
        globalData.settings.outdir = tempDir.path(percentEncoded: false).copyCString()
        globalData.settings.lplexoutdir = tempDir.path(percentEncoded: false).copyCString()
        globalData.settings.indir = tempDir.path(percentEncoded: false).copyCString()
        globalData.settings.settingsfile = tempDir.path(percentEncoded: false).copyCString()
        globalData.settings.dvdisopath = tempDir.path(percentEncoded: false).copyCString()
        globalData.settings.stillpicdir = tempDir.path(percentEncoded: false).copyCString()
        
        
        let provider = UnsafeMutablePointer<CChar>.allocate(capacity: 30)
        provider.initialize(repeating: 0, count: 30)
        command.provider = provider
        command.img = img0
        command.ngroups = numOfGroups
        var numOfTracks = UnsafeMutablePointer<UInt8>.allocate(capacity: 9)
        numOfTracks.initialize(repeating: 0, count: 9)
        defer {
//            numOfTracks.deallocate()
        }
        var files = UnsafeMutablePointer<UnsafeMutablePointer<fileinfo_t>?>(nil)
        let givenChannels = UnsafeMutablePointer<GivenChannels>.allocate(capacity: 9)
        defer {
//            givenChannels.deallocate()
        }
        files = dynamic_memory_allocate(files, givenChannels, &numOfTracks, numOfGroups, numOfGroups, 0, &globalData) // TODO: remove?
        
        var expectedTotalTracks = 0
        for (i, group) in groups.enumerated() {
            group.generateFileInfo(fileInfo: files![i]!)
            numOfTracks[i] = UInt8(group.files.count)
            expectedTotalTracks += group.files.count
        }
        command.files = files
        command.ntracks = numOfTracks
        scan_audiofile_characteristics(&command, &globalData)
        
        
        var numOfTitles = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(numOfGroups))
        let numOfTitleTracks = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: Int(numOfGroups))
        let numOfTitleLength = UnsafeMutablePointer<UnsafeMutablePointer<UInt64>?>.allocate(capacity: Int(numOfGroups))
        let numOfTitlePics = UnsafeMutablePointer<UnsafeMutablePointer<UInt16>?>.allocate(capacity: Int(numOfGroups))
        defer {
//            numOfTitles.deallocate()
//            numOfTitleTracks.deallocate()
//            numOfTitleLength.deallocate()
//            numOfTitlePics.deallocate()
        }
        
        var totalSampleBytes: UInt64 = 0
        var numFiles = Array<Int>(repeating: 0, count: Int(numOfGroups))
        for i in 0..<Int(numOfGroups) {
            numFiles[i] = Int(command.ntracks[i])
            for j in 0..<numFiles[i] {
                if command.files[i]![j].cga == 0 || command.files[i]![j].cga == 0xff {
                    command.files[i]![j].cga = wav2cga_channels(&command.files[i]![j], &globalData)
                }
                command.files[i]![j].contin_track = calc_countin_track(j, numFiles[i])
                
                if command.files[i]![j].type == AFMT_MLP {
                    throw AuthorError.unsupportedFileType(command.files[i]![j].type, groups[i].files[j])
                } else {
                    if ((command.files[i]![j].samplerate > 48000 && command.files[i]![j].bitspersample == 24) || command.files[i]![j].samplerate > 96000)
                        && command.files[i]![j].channels >= 5 {
                            throw AuthorError.unsupportedBitDepthOrSampleRate(groups[i].files[j])
                    }
                }
                totalSampleBytes += command.files[i]![j].numbytes;
            }
        }
        
        
        
        
        let totalTrackCount = create_tracktables(&command, numOfGroups, &numOfTitles, numOfTitleTracks, numOfTitleLength, numOfTitlePics, &globalData)
//        precondition(expectedTotalTracks == totalTrackCount)
        
        print("total tracks \(totalTrackCount)")
        
        
        var sectors = sect()
        sectors.amg = UInt8(SIZE_AMG + (globalData.text ? 1 : 0) + (globalData.topmenu <= TS_VOB_TYPE ? 1 : 0))
        sectors.samg = UInt8(SIZE_SAMG)
        sectors.asvs = UInt8(((command.img.pointee.count > 0) || (command.img.pointee.stillvob != nil) || (command.img.pointee.active)) ? SIZE_ASVS : 0)
        sectors.topvob = 0
        sectors.stillvob = 0
        memset(&sectors.atsi, 0, 9) // sizeof sectors.atsi
        
        var numOfAobFiles: Int32 = 0
        var numOfAtsiFiles: Int32 = 0
        let atsiSectors = UnsafeMutablePointer<UInt8>.allocate(capacity: 9)
        atsiSectors.initialize(repeating: 0, count: 9)
        defer {
//            atsiSectors.deallocate()
        }
        for i in 0..<Int(numOfGroups) {
            numOfAobFiles += create_ats(audioTsDir, Int32(i+1), command.files[i]!, Int32(numFiles[i]), &globalData)
            numOfAtsiFiles += create_atsi(&command, audioTsDir, UInt8(i), &atsiSectors[i], numOfTitlePics[i], &globalData)
        }
        sectors.atsi = (atsiSectors[0], atsiSectors[1], atsiSectors[2], atsiSectors[3], atsiSectors[4], atsiSectors[5],
                        atsiSectors[6], atsiSectors[7], atsiSectors[8])
        
        let numOfAsvFiles: Int32 = 0
        var startsector = STARTSECTOR
        startsector += 3 // AUDIO_TS.IFO + AUDIO_TS.BUP + SAMG
        + ((command.img.pointee.tsvob != nil && sectors.topvob != 0) ? 1 : 0)   // AUDIO_TS.VOB
        + numOfAsvFiles // AUDIO_SV.VOB + AUDIO_SV.IFO + AUDIO_SV.BUP
        + numOfAobFiles + numOfAtsiFiles // num of ATS_XX_0.IFO + ATS_XX_0.BUP files
        
        let lastSector = create_samg(audioTsDir, &command, &sectors, &globalData, UInt32(startsector))
        
        print("last sector \(lastSector)")
        
        let numOfAmgFiles = create_amg(audioTsDir,
                                       &command,
                                       &sectors,
                                       nil,
                                       nil,
                                       &numOfTitles,
                                       numOfTitleTracks,
                                       numOfTitleLength,
                                       &globalData)
        precondition(numOfAmgFiles > 0)
        
        print("num of amg files \(numOfAmgFiles)")
        
        
        
    }
    
    
}

extension Author.Group {
    
    func generateFileInfo(fileInfo: UnsafeMutablePointer<fileinfo_t>) {
        for (i, file) in files.enumerated() {
            fileInfo[i].filename = file.path(percentEncoded: false).copyCString()
        }
    }
    
}

extension String {
    func copyCString() -> UnsafeMutablePointer<Int8> {
        let data = self.data(using: .utf8)!
        let buffer = malloc(data.count)!
        buffer.withMemoryRebound(to: UInt8.self, capacity: data.count) { pointer in
            data.copyBytes(to: pointer, count: data.count)
        }
        return buffer.assumingMemoryBound(to: Int8.self)
    }
}


typealias GivenChannels = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
let globalGivenChannels: GivenChannels = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)

