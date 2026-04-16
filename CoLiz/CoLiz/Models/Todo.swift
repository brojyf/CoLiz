//
//  Todo.swift
//  CoList
//
//  Created by 江逸帆 on 2/10/26.
//

import Foundation

struct Todo: Identifiable, Codable {
    var id: String
    var groupId: String
    var message: String
    var done: Bool
    var createdBy: String
    var createdByName: String
    var doneBy: String
    var updatedAt: Date
    var createdAt: Date
}

extension Todo {
    enum CodingKeys: String, CodingKey {
        case id
        case groupId
        case message
        case done
        case createdBy
        case createdByName
        case doneBy
        case updatedAt
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        groupId = try container.decode(String.self, forKey: .groupId)
        message = try container.decode(String.self, forKey: .message)
        done = try container.decode(Bool.self, forKey: .done)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        createdByName = try container.decodeIfPresent(String.self, forKey: .createdByName) ?? ""
        doneBy = try container.decodeIfPresent(String.self, forKey: .doneBy) ?? ""
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

extension Todo {
    func toggle(at time: Date = Date()) -> Todo {
        let nextDone = !done
        return Todo(
            id: id,
            groupId: groupId,
            message: message,
            done: nextDone,
            createdBy: createdBy,
            createdByName: createdByName,
            doneBy: "",
            updatedAt: time,
            createdAt: createdAt
        )
    }

    static func mockList() -> [Todo] {
        return [
            Todo(
                id: "1",
                groupId: "work",
                message: "完成 SwiftUI 界面原型设计",
                done: true,
                createdBy: "阿强",
                createdByName: "阿强",
                doneBy: "阿强",
                updatedAt: Date().addingTimeInterval(-3600), // 1小时前
                createdAt: Date().addingTimeInterval(-86400) // 1天前
            ),
            Todo(
                id: "2",
                groupId: "work",
                message: "审查后端 Go 语言结构体",
                done: false,
                createdBy: "项目经理",
                createdByName: "项目经理",
                doneBy: "",
                updatedAt: Date(),
                createdAt: Date().addingTimeInterval(-7200) // 2小时前
            ),
            Todo(
                id: "3",
                groupId: "life",
                message: "健身房锻炼 1 小时",
                done: false,
                createdBy: "自己",
                createdByName: "自己",
                doneBy: "",
                updatedAt: Date(),
                createdAt: Date().addingTimeInterval(-1800) // 30分钟前
            ),
            Todo(
                id: "4",
                groupId: "study",
                message: "学习 Swift 并发编程 (Async/Await)",
                done: false,
                createdBy: "系统",
                createdByName: "系统",
                doneBy: "",
                updatedAt: Date(),
                createdAt: Date().addingTimeInterval(-43200) // 12小时前
            )
        ]
    }
}
