// main.swift
// Speaker Diarization Spike - CLI Entry Point

import Foundation

// Flush stdout after each print
setbuf(__stdoutp, nil)
runSpikeFromCommandLine()
