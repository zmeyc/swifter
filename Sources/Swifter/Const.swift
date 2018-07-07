//
//  Const.swift
//  Swifter
//
//  Created by Damian Kolakowski on 17/12/15.
//  Copyright © 2015 Damian Kołakowski. All rights reserved.
//

import Foundation
#if os(Linux)
    import Glibc
    import NSLinux
#endif

public struct Constants {
    
    public static let VERSION      = "1.0.2"
    public static let DEFAULT_PORT = in_port_t(8080)
    
    public static let CR           = UInt8(13)
    public static let NL           = UInt8(10)
}
