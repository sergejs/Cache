//
//  File.swift
//
//
//  Created by Sergejs Smirnovs on 17.11.21.
//

import Foundation
import ServiceContainer
import UIKit

public typealias ImageCache = Cache<String, UIImage>

private struct ImageCacheKey: InjectionKey {
    static var currentValue = ImageCache()
}

public extension InjectedValues {
    var imageCache: ImageCache {
        get { Self[ImageCacheKey.self] }
        set { Self[ImageCacheKey.self] = newValue }
    }
}
