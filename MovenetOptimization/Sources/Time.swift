//
//  Time.swift
//  MovenetOptimization
//
//  Created by sh.hong on 8/9/24.
//

import Foundation

public struct Times {
    public var preprocessing: TimeInterval
    public var inference: TimeInterval
    public var postprocessing: TimeInterval
    public var total: TimeInterval { preprocessing + inference + postprocessing }
}
