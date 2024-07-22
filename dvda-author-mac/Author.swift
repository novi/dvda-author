//
//  Author.swift
//  dvda-author-mac
//
//  Created by Yusuke Ito on 7/22/24.
//

import Foundation

class Author {
    
    struct Group {
        let files: [URL]
    }
    
    init() {
        
    }
    
    func build(groups: [Group]) throws {
        
        let numOfGroups = UInt8(groups.count)
        precondition(groups.count <= 9)
        
        
        // clean and create work directory
        let tempDir = FileManager.default.temporaryDirectory
        print(tempDir)
        
        
        // init variable
        var globalData = globalData()
        var command = command_t()
        defer {
            free_memory(&command, &globalData)
        }
        globalData.topmenu = 5 // No Menu
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
        
        let totalTrackCount = create_tracktables(&command, numOfGroups, &numOfTitles, numOfTitleTracks, numOfTitleLength, numOfTitlePics, &globalData)
        precondition(expectedTotalTracks == totalTrackCount)
        
        print("total tracks \(totalTrackCount)")
        
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
