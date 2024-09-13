import SwiftUI

struct BallLoader: View {
    
    private let bounce: Bool
    private var bounceVar: Int {
        if bounce { return 1 }
        return 0
    }
    private let animationDuration: CGFloat
    private let animationSegments = 20.0
    private let segmentDuration: CGFloat
    private let fps: CGFloat
    private let colors: [Color]
    private var totalProgress: Double { return value / animationDuration }
    
    @State private var ballPositions: [CGPoint?] = Array(repeating: nil, count: 5)
    @State private var timer: Timer?
    @State private var value: CGFloat = 0.0
    @State private var paths: [Path]? = nil
    
    // Below are optimal FPS pairings because the animation segments are so short
    // 65fps/30sec, 25 sec, 20sec
    // 70fps/15sec
    // 80fps/12 seec
    // 85fps/13sec
    // 45fps/45 sec
    init(duration: CGFloat, primaryColor: Color, secondaryColor: Color, bounce: Bool = false) {
        switch duration {
            case 45: self.fps = 45
            case 15: self.fps = 70
            case 13: self.fps = 85
            case 12: self.fps = 80
            default: self.fps = 65
                
        }
        self.segmentDuration = duration / Double(animationSegments)
        self.animationDuration = duration
        self.colors = [secondaryColor, primaryColor, primaryColor, secondaryColor, primaryColor]
        self.bounce = bounce
        
    }
    
    func allPositions(geo: GeometryProxy) -> [CGPoint] {
        return Array(0..<4).map { CGPoint(x: geo.size.width / 3 * CGFloat($0), y: geo.size.height / 2) }
    }
    
    func ballStartPosition(for ball: CGFloat, geo: GeometryProxy) -> CGPoint {
        
        let positions = allPositions(geo: geo)
        
        for i in 0..<5 {
            if totalProgress < (ball + CGFloat(i) * 5) * 0.05 {
                let index = Int(ball) - 1 + i
                return positions[index % 4]
            }
        }
        
        return positions[(Int(ball) - 1) % 4]
    }

    var body: some View {
        ZStack {
            
            Color.white.ignoresSafeArea()
            
            GeometryReader { geo in
                ZStack {
                    if let paths = paths {
                        
                        ForEach(0..<colors.count, id: \.description) { ballNum in
                            if ballNum % 2 == 0 {
                                
                                Circle()
                                    .foregroundStyle(colors[ballNum])
                                    .frame(width: geo.size.width / 6)
                                    .position(ballPositions[ballNum]!)
                                
                            } else {
                                
                                Circle()
                                    .stroke(colors[ballNum], lineWidth: geo.size.width < 150 ? 1 : 2)
                                    .frame(width: geo.size.width / 7)
                                    .position(ballPositions[ballNum]!)
                            }
                        }
                    }
                }
                .onAppear {
                    generatePaths(geo: geo)
                    
                    timer = Timer.scheduledTimer(withTimeInterval: 1/fps, repeats: true) { _ in
                        if value >= animationDuration { value = 0.0 }
                        else { value += 1.0 / fps }
                        
                        updatePosition(geo: geo)
                    }
                }
            }
            .frame(width: 200, height: 300)
        }
    }
    
    func bounceBackPath(ball: Int, bounceNum: Int, geo: GeometryProxy) -> Path {
        let width = geo.size.width
        let height = geo.size.height
        let xPosition: CGFloat = width / 3.0 * CGFloat((bounceNum + ((ball - 1) % 4)) % 4)
        
        var result = Path()
        result.move(to: CGPoint(x: xPosition, y: height / 2))
        
        if ball % 2 == 1 - bounceVar { result.addLine(to: CGPoint(x: xPosition, y: height / (bounceNum % 2 == 1 ? 1.9 : 2.1))) }
        else { result.addLine(to: CGPoint(x: xPosition, y: height / (bounceNum % 2 == 1 ? 2.1 : 1.9))) }
        
        result.addLine(to: CGPoint(x: xPosition, y: height / 2))
        
        return result
    }
    
    func updateBallPosition(ballNum: Int, newPosition: Path, bouncePath: Bool, start: CGFloat, end: CGFloat) {
        if totalProgress > start && totalProgress < end {
            let customSegProgress = customSegmentProgress(from: start, to: end)
            
            var path: Path {
                if bouncePath { return newPosition.trimmedPath(from: 0, to: customSegProgress) }
                return newPosition.trimmedPath(from: 0, to: customEaseOutIn(progress: customSegProgress))
            }
            
            ballPositions[ballNum - 1] = path.currentPoint ?? .zero
        }
    }
    
    func updatePosition(geo: GeometryProxy) {
        
        let mainStartsAndEnds: [[(start: CGFloat, end: CGFloat)]] = [
            [ (0.0, 0.05), (0.238, 0.301), (0.488, 0.551), (0.738, 0.801) ],
            [ (0.047, 0.097), (0.298, 0.348), (0.548, 0.598), (0.798, 0.848) ],
            [ (0.346, 0.396), (0.596, 0.646), (0.845, 0.895), (0.095, 0.145), ],
            [ (0.643, 0.693), (0.893, 0.943), (0.143, 0.193), (0.394, 0.444) ],  // i have no clue
            [ (0.191, 0.241), (0.44, 0.49), (0.691, 0.741), (0.941, 1.0) ]
        ]
        
        let bounceStartsAndEnds: [[(start: CGFloat, end: CGFloat)]] = [
            [(0.05, 0.06), (0.301, 0.311), (0.551, 0.561), (0.801, 0.811)],
            [(0.097, 0.107), (0.348, 0.358), (0.598, 0.608), (0.848, 0.858)],
            [(0.396, 0.406), (0.646, 0.656), (0.895, 0.905), (0.145, 0.155),],
            [(0.193, 0.203), (0.444, 0.454), (0.693, 0.703), (0.943, 0.953)],
            [(0.241, 0.251), (0.49, 0.5), (0.741, 0.751), (0.0, 0.01)]
        ]
        
        for i in 0..<4 {
            
            for ball in 1...5 {
                
                var newPositionIndexCalculation: Int {
                    switch ball {
                        case 1, 5: return i
                        case 2, 4: return (i + 1) % 4
                        case 3: return (i + 3) % 4
                        default: return i
                    }
                }
                
                updateBallPosition(
                    ballNum: ball,
                    newPosition: paths![newPositionIndexCalculation],
                    bouncePath: false,
                    start: mainStartsAndEnds[ball - 1][i].start,
                    end: mainStartsAndEnds[ball - 1][i].end
                )
                
                
                if ball == 3 { continue }
                updateBallPosition(
                    ballNum: ball,
                    newPosition: bounceBackPath(ball: ball, bounceNum: i + 1, geo: geo),
                    bouncePath: true,
                    start: bounceStartsAndEnds[ball - 1][i].start,
                    end: bounceStartsAndEnds[ball - 1][i].end
                )
            }
            
            updateBallPosition(
                ballNum: 3,
                newPosition: bounceBackPath(ball: 3, bounceNum: max(1, ((i + 2) % 5)), geo: geo),
                bouncePath: true,
                start: bounceStartsAndEnds[2][i].start,
                end: bounceStartsAndEnds[2][i].end)
        }
        
        if totalProgress < 0.0 { ballPositions[0] = ballStartPosition(for: 1, geo: geo)}
    }
    
    func customSegmentProgress(from start: CGFloat, to end: CGFloat) -> CGFloat {
        let difference = end - start
        return (totalProgress - start) / difference
    }
    
    func segmentProgress() -> Double {
        let segmentDurationProgress = value.truncatingRemainder(dividingBy: segmentDuration)
        let segmentProgress = segmentDurationProgress / segmentDuration
        return segmentProgress
    }
    
    // This is a numerically derived cubic bezier function. SwiftUI doesn't come with a "ease-out-in" function so I had to recreate numerically since I was having trouble getting the bezier function to work with the bounce segment of the animation
    func customEaseOutIn(progress: CGFloat) -> CGFloat {
        let thresholds: [(CGFloat, CGFloat)] = [
            (0.0, 0.0), (0.01, 0.06), (0.02, 0.09), (0.03, 0.14), (0.05, 0.20),
            (0.07, 0.25), (0.1, 0.31), (0.15, 0.39), (0.2, 0.43),  (0.25, 0.47),
            (0.3, 0.48), (0.32, 0.486), (0.35, 0.492), (0.38, 0.496), (0.40, 0.4975),
            (0.45, 0.50), (0.50, 0.50), (0.55, 0.50), (0.60, 0.51), (0.65, 0.51),
            (0.70, 0.52), (0.75, 0.55), (0.80, 0.572), (0.83, 0.599), (0.85, 0.63),
            (0.88, 0.6625), (0.90, 0.7), (0.93, 0.77), (0.94, 0.79), (0.95, 0.81),
            (0.96, 0.841), (0.97, 0.875), (0.98, 0.911), (0.99, 0.953), (1.0, 1.0)
        ]
        
        let value = thresholds.first(where: { progress < $0.0 })?.1
        
        return value ?? 1.0
    }
    
    func generatePaths(geo: GeometryProxy) {
        let width = geo.size.width
        let height = geo.size.height
        
        let points = allPositions(geo: geo)
        
        let controlPoints: [[CGPoint]] = [
            [CGPoint(x: 0, y: height / 6),     CGPoint(x: width / 3, y: height / 6)],
            [CGPoint(x: width / 3, y: height), CGPoint(x: width / 3 * 2, y: height)],
            [CGPoint(x: width / 3 * 2, y: 0),  CGPoint(x: width, y: 0)],
            [CGPoint(x: width, y: height),     CGPoint(x: 0, y: height)]
        ]
        
        var newPaths: [Path] = []
        
        for pointNum in 0..<points.count {
            var path: Path {
                var result = Path()
                result.move(to: points[pointNum])
                result.addCurve(
                    to: points[pointNum == points.count - 1 ? 0 : pointNum + 1],
                    control1: controlPoints[pointNum][0],
                    control2: controlPoints[pointNum][1]
                )
                return result
            }
            newPaths.append(path)
        }
        
        for i in 0..<5 { ballPositions[i] = ballStartPosition(for: CGFloat(i + 1), geo: geo) }
        
        self.paths = newPaths
        
    }
}
