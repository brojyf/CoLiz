//
//  ErrorPresenter‘.swift
//  CoList
//
//  Created by 江逸帆 on 2/14/26.
//

import Foundation

import SwiftUI
import Combine

// 1) 全局只负责“展示”
@MainActor
final class ErrorPresenter: ObservableObject {
    @Published var message: String?

    func show(_ msg: String) { message = msg }
    func clear() { message = nil }
}
