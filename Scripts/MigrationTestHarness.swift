// Supplementary macOS SwiftData checks. The iOS-hosted test methods are compiled unchanged
// apart from imports, with these assertion adapters. This is not a simulator XCTest run.
import Foundation

class XCTestCase {}
enum MigrationCheckError: Error { case missingValue }

func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T,
                                  file: StaticString = #filePath, line: UInt = #line) {
    precondition(actual == expected, "Mismatch at \(file):\(line): \(actual) != \(expected)")
}
func XCTAssertNotEqual<T: Equatable>(_ actual: T, _ expected: T,
                                     file: StaticString = #filePath, line: UInt = #line) {
    precondition(actual != expected, "Expected distinct values at \(file):\(line)")
}
func XCTAssertEqual(_ actual: Double, _ expected: Double, accuracy: Double,
                    file: StaticString = #filePath, line: UInt = #line) {
    precondition(actual.isFinite && expected.isFinite && abs(actual - expected) <= accuracy,
                 "Mismatch at \(file):\(line): \(actual) != \(expected) ± \(accuracy)")
}
func XCTAssertNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) {
    precondition(value == nil, "Expected nil at \(file):\(line)")
}
func XCTAssertTrue(_ condition: Bool, file: StaticString = #filePath, line: UInt = #line) {
    precondition(condition, "Expected true at \(file):\(line)")
}
func XCTUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) throws -> T {
    guard let value else {
        print("Missing value at \(file):\(line)")
        throw MigrationCheckError.missingValue
    }
    return value
}
