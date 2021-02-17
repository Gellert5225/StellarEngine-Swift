//
//  StellarEngineMacOSTests.swift
//  StellarEngineMacOSTests
//
//  Created by Gellert Li on 2/13/21.
//  Copyright © 2021 Gellert. All rights reserved.
//

import XCTest
@testable import StellarEngineMacOS

var tree: ResourceTree!

class StellarEngineMacOSTests: XCTestCase {

    override func setUpWithError() throws {
        super.setUp()
        tree = ResourceTree(name: "root", isDirectory: true)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testTree() throws {
        let child_1 = ResourceTree(name: "dir_1", isDirectory: true)
        let child_2 = ResourceTree(name: "dir_2", isDirectory: true)
        let child_3 = ResourceTree(name: "file_1", isDirectory: false)
        
        child_1.add(child: child_3)
        
        tree.add(child: child_1)
        tree.add(child: child_2)
        
        XCTAssertEqual(tree.children[0].name, "dir_1", "Test failed. Expected value: dir_1, actual: \(tree.children[0].name)")
        XCTAssertEqual(tree.children[1].name, "dir_2", "Test failed. Expected value: dir_1, actual: \(tree.children[1].name)")
        XCTAssertEqual(tree.children[0].children[0].name, "file_1", "Test failed. Expected value: dir_1, actual: \(tree.children[0].children[0].name)")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
