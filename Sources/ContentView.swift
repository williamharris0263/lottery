import SwiftUI

// 定义奖项枚举
enum Prize: String {
    case first = "一等奖"
    case second = "二等奖"
    case third = "三等奖"
    case none = "未中奖"
}

struct ContentView: View {
    // 设置参数
    @State private var maxParticipants: Int = 100
    @State private var firstPrizeRatio: Double = 10
    @State private var secondPrizeRatio: Double = 10
    @State private var thirdPrizeRatio: Double = 50
    
    // 运行状态
    @State private var prizePool: [Prize] = []
    @State private var drawnCount: Int = 0
    @State private var resultMessage: String = "等待抽奖..."
    @State private var showResultCenter: Bool = false
    
    // 统计数据 (已出 / 剩余)
    @State private var firstDrawn: Int = 0
    @State private var secondDrawn: Int = 0
    @State private var thirdDrawn: Int = 0
    
    var firstTotal: Int { Int(Double(maxParticipants) * (firstPrizeRatio / 100.0)) }
    var secondTotal: Int { Int(Double(maxParticipants) * (secondPrizeRatio / 100.0)) }
    var thirdTotal: Int { Int(Double(maxParticipants) * (thirdPrizeRatio / 100.0)) }

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 顶部：参数设置区
                VStack(spacing: 15) {
                    HStack {
                        Text("总人数上限:")
                        Spacer()
                        TextField("100", value: $maxParticipants, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    RatioSlider(title: "一等奖比例 (%)", value: $firstPrizeRatio, color: .red)
                    RatioSlider(title: "二等奖比例 (%)", value: $secondPrizeRatio, color: .orange)
                    RatioSlider(title: "三等奖比例 (%)", value: $thirdPrizeRatio, color: .blue)
                    
                    Button("重置并初始化奖池") {
                        setupPool()
                    }
                    .padding(.top, 10)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                
                Spacer()
                
                // 中部：抽奖按钮与结果
                VStack(spacing: 30) {
                    Text(resultMessage)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(showResultCenter ? .primary : .secondary)
                        .multilineTextAlignment(.center)
                        .frame(height: 60)
                    
                    Button(action: drawPrize) {
                        Text("立即抽奖")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.white)
                            .frame(width: 160, height: 160)
                            .background(
                                Circle()
                                    .fill(LinearGradient(gradient: Gradient(colors: [Color.pink, Color.orange]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .shadow(color: .pink.opacity(0.5), radius: 10, x: 0, y: 10)
                            )
                    }
                    .disabled(prizePool.isEmpty)
                    .scaleEffect(prizePool.isEmpty ? 0.9 : 1.0)
                    .animation(.spring(), value: prizePool.isEmpty)
                }
                
                Spacer()
                
                // 底部：数据统计看板
                VStack(spacing: 10) {
                    Text("抽奖进度: \(drawnCount) / \(maxParticipants)")
                        .font(.headline)
                    
                    Divider()
                    
                    HStack(alignment: .top, spacing: 20) {
                        StatView(title: "一等奖", drawn: firstDrawn, remain: firstTotal - firstDrawn)
                        StatView(title: "二等奖", drawn: secondDrawn, remain: secondTotal - secondDrawn)
                        StatView(title: "三等奖", drawn: thirdDrawn, remain: thirdTotal - thirdDrawn)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .onAppear { setupPool() }
    }
    
    // 初始化奖池算法
    func setupPool() {
        prizePool.removeAll()
        firstDrawn = 0; secondDrawn = 0; thirdDrawn = 0; drawnCount = 0
        
        let noneCount = maxParticipants - firstTotal - secondTotal - thirdTotal
        
        for _ in 0..<firstTotal { prizePool.append(.first) }
        for _ in 0..<secondTotal { prizePool.append(.second) }
        for _ in 0..<thirdTotal { prizePool.append(.third) }
        for _ in 0..<max(0, noneCount) { prizePool.append(.none) }
        
        prizePool.shuffle() // 核心：打乱数组保证概率随机
        resultMessage = "奖池已就绪，等待抽奖..."
        showResultCenter = false
    }
    
    // 抽奖动作
    func drawPrize() {
        guard !prizePool.isEmpty else {
            resultMessage = "活动已结束！"
            return
        }
        
        // 增加动效反馈
        withAnimation(.easeInOut(duration: 0.2)) {
            showResultCenter = true
        }
        
        let result = prizePool.removeLast() // 弹出最后一个元素
        drawnCount += 1
        
        switch result {
        case .first:
            firstDrawn += 1
            resultMessage = "🎉 恭喜您，获得了一等奖！"
        case .second:
            secondDrawn += 1
            resultMessage = "✨ 恭喜您，获得了二等奖！"
        case .third:
            thirdDrawn += 1
            resultMessage = "🎈 恭喜您，获得了三等奖！"
        case .none:
            resultMessage = "🥺 很遗憾，本次未中奖"
        }
    }
}

// 辅助 UI 组件：比例滑动条
struct RatioSlider: View {
    var title: String
    @Binding var value: Double
    var color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text("\(Int(value))%")
                .font(.subheadline)
                .bold()
                .foregroundColor(color)
        }
        Slider(value: $value, in: 0...100, step: 1)
            .accentColor(color)
    }
}

// 辅助 UI 组件：统计小块
struct StatView: View {
    var title: String
    var drawn: Int
    var remain: Int
    
    var body: some View {
        VStack(spacing: 5) {
            Text(title).font(.subheadline).bold()
            Text("已出: \(drawn)").font(.caption).foregroundColor(.secondary)
            Text("剩余: \(remain)").font(.caption).foregroundColor(remain == 0 ? .red : .green)
        }
    }
}