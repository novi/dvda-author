//
//  BridgingHeader.h
//  dvda-author
//
//  Created by Yusuke Ito on 7/22/24.
//

#ifndef BridgingHeader_h
#define BridgingHeader_h

#define WITHOUT_sox 1
#define WITHOUT_lplex 1
#define WITHOUT_FLAC 1
#define HAVE_core_BUILD 1
#define XCODE 1

#include "amg.h"
#include "ats.h"
#include "atsi.h"
#include "samg.h"

static uint8_t calc_countin_track(long j, long numfiles) {
    return (uint8_t)(j != (numfiles) - 1);
}

#endif /* BridgingHeader_h */
