//
//  ShareURLExtractorTests.swift
//  nextBookmarkTests
//
//  Exercises ShareURLExtractor against NSItemProviders built the same way
//  the Share Extension receives them from iOS, so we don't need to launch
//  the ShareExtension target (a separate module nextBookmarkTests can't
//  import) to cover its core "what URL do we save?" decision.
//

import XCTest
@testable import nextBookmark

final class ShareURLExtractorTests: XCTestCase {

    func testExtractsURLAttachment() {
        let provider = NSItemProvider(object: URL(string: "https://example.com/page")! as NSURL)
        let item = NSExtensionItem()
        item.attachments = [provider]

        let expectation = expectation(description: "extract")
        ShareURLExtractor.extractURL(from: item) { result in
            XCTAssertEqual(result, "https://example.com/page")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testExtractsHttpTextAttachment() {
        let provider = NSItemProvider(object: "https://example.com/from-text" as NSString)
        let item = NSExtensionItem()
        item.attachments = [provider]

        let expectation = expectation(description: "extract")
        ShareURLExtractor.extractURL(from: item) { result in
            XCTAssertEqual(result, "https://example.com/from-text")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testIgnoresNonURLText() {
        let provider = NSItemProvider(object: "just some shared text, not a link" as NSString)
        let item = NSExtensionItem()
        item.attachments = [provider]

        let expectation = expectation(description: "extract")
        ShareURLExtractor.extractURL(from: item) { result in
            XCTAssertNil(result)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testReturnsNilForNoAttachments() {
        let item = NSExtensionItem()
        item.attachments = []

        let expectation = expectation(description: "extract")
        ShareURLExtractor.extractURL(from: item) { result in
            XCTAssertNil(result)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testReturnsNilForNilItem() {
        let expectation = expectation(description: "extract")
        ShareURLExtractor.extractURL(from: nil) { result in
            XCTAssertNil(result)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}
