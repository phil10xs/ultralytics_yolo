import XCTest
@testable import Runner

final class YoloPostProcessorTests: XCTestCase {

    private var pp: YoloPostProcessor!
    private var labels: [String]!

    override func setUp() {
        super.setUp()
        labels = (0..<80).map { "cls\($0)" }
        pp = YoloPostProcessor(labels: labels, inputSize: 640, conf: 0.25, iou: 0.45)
    }

    override func tearDown() {
        pp = nil
        labels = nil
        super.tearDown()
    }

    func test_decode84xN_ObjectnessTimesClassScore_producesDetection() throws {
        // [84][N] where N=1
        var out = Array(repeating: [Float](repeating: 0, count: 1), count: 84)

        // bbox (pixel space)
        out[0][0] = 320  // cx
        out[1][0] = 320  // cy
        out[2][0] = 200  // w
        out[3][0] = 100  // h

        // objectness
        out[4][0] = 0.9

        // class7 score at channel 5 + 7 = 12
        out[5 + 7][0] = 0.9

        let dets = pp.decode84xN(out)

        guard let d = dets.first else {
            XCTFail("Expected >= 1 detection, got 0. Decoder indexing likely mismatched.")
            return
        }

        XCTAssertEqual(d.cls, 7)
        XCTAssertEqual(d.label, "cls7")
        XCTAssertGreaterThan(d.score, 0.25)
    }

    func test_decode84xN_normalizesRect_to0to1() throws {
        // Lower conf to avoid filtering issues during geometry test
        pp = YoloPostProcessor(labels: labels, inputSize: 640, conf: 0.01, iou: 0.45)

        var out = Array(repeating: [Float](repeating: 0, count: 1), count: 84)
        out[0][0] = 320
        out[1][0] = 320
        out[2][0] = 64
        out[3][0] = 64
        out[4][0] = 1.0      // objectness
        out[5 + 0][0] = 0.8  // class0

        let dets = pp.decode84xN(out)

        guard let d = dets.first else {
            XCTFail("Expected detection, got 0. Check conf threshold or channel indexing.")
            return
        }

        let r = d.rect
        XCTAssertTrue(r.minX >= 0 && r.minY >= 0)
        XCTAssertTrue(r.maxX <= 1 && r.maxY <= 1)

        // Should be near center
        XCTAssertGreaterThan(r.midX, 0.45)
        XCTAssertLessThan(r.midX, 0.55)
        XCTAssertGreaterThan(r.midY, 0.45)
        XCTAssertLessThan(r.midY, 0.55)
    }

    func test_nms_suppressesHighIoU() throws {
        // conf=0 so we only test NMS
        pp = YoloPostProcessor(labels: labels, inputSize: 640, conf: 0.0, iou: 0.5)

        let a = YoloPostProcessor.Detection(
            rect: CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.4),
            cls: 0,
            score: 0.9,
            label: "cls0"
        )
        let b = YoloPostProcessor.Detection(
            rect: CGRect(x: 0.12, y: 0.12, width: 0.4, height: 0.4),
            cls: 0,
            score: 0.8,
            label: "cls0"
        )

        let kept = pp.nms([a, b], thr: 0.5)
        XCTAssertEqual(kept.count, 1)
        XCTAssertEqual(kept.first?.score, 0.9)
    }

    func test_iou_basicSanity() throws {
        let a = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        let b = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)

        let v = pp.iou(a, b)
        XCTAssertGreaterThan(v, 0)
        XCTAssertLessThan(v, 1)
    }
}

