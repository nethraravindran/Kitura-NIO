/*
 * Copyright IBM Corporation 2016, 2017, 2018
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import XCTest
@testable import KituraNetTests

// http://stackoverflow.com/questions/24026510/how-do-i-shuffle-an-array-in-swift
extension MutableCollection {
    mutating func shuffle() {
        let c = count
        guard c > 1 else { return }

        srand(UInt32(time(nil)))
        for (firstUnshuffled, unshuffledCount) in zip(indices, stride(from: c, to: 1, by: -1)) {
            let d: IndexDistance = numericCast(random() % numericCast(unshuffledCount))
            guard d != 0 else { continue }
            let i = index(firstUnshuffled, offsetBy: d)
            swapAt(firstUnshuffled, i)
        }
    }
}

extension Sequence {
    func shuffled() -> [Iterator.Element] {
        var result = Array(self)
        result.shuffle()
        return result
    }
}

XCTMain([
    testCase(BufferListTests.allTests.shuffled()),
    testCase(ClientRequestTests.allTests.shuffled()),
    testCase(HTTPResponseTests.allTests.shuffled()),
    testCase(HTTPStatusCodeTests.allTests.shuffled()),
    testCase(LargePayloadTests.allTests.shuffled()),
    testCase(LifecycleListenerTests.allTests.shuffled()),
    testCase(MiscellaneousTests.allTests.shuffled()),
    testCase(ParserTests.allTests.shuffled()),
    testCase(ClientE2ETests.allTests.shuffled()),
    testCase(PipeliningTests.allTests.shuffled()),
    testCase(RegressionTests.allTests.shuffled()),
    testCase(MonitoringTests.allTests.shuffled())
].shuffled())
