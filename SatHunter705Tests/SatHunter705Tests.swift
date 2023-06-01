//
//  SatHunter705Tests.swift
//  SatHunter705Tests
//
//  Created by Zhuo Peng on 5/28/23.
//

import XCTest

final class SatHunter705Tests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testSatInfoManager() throws {
      var mgr = SatInfoManager()
      print("\(mgr.satellites[25544].debugDescription)")
    }

}
