import SwiftUI
import UIKit

// --- 1. 数据模型 ---
struct Prize: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var count: Int
    var drawn: Int = 0
}

enum DrawStatus {
    case idle, drawing, wonBig, wonSmall, missed
}

// 独立的粒子数据结构
struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var rotation: Double
    var scale: CGFloat
    var emoji: String
}

// --- 2. 抽奖逻辑控制器 ---
class LotteryManager: ObservableObject {
    @Published var activeMaxParticipants: Int = 100
    @Published var activePrizes: [Prize] = []
    @Published var prizePool: [UUID?] = []
    @Published var drawnCount: Int = 0
    @Published var currentResult: String = "点击开启好运"
    
    @Published var isDrawing: Bool = false
    @Published var drawStatus: DrawStatus = .idle
    @Published var flashTrigger: Bool = false // 爆闪触发器
    @Published var showConfetti: Bool = false // 礼花触发器
    
    @Published var configMaxParticipants: Int = 100
    @Published var configPrizes: [Prize] = [
        Prize(name: "一等奖", count: 10), Prize(name: "二等奖", count: 10), Prize(name: "三等奖", count: 50)
    ]

    private let greetings = ["✨ 天呐！", "🎉 运气爆表！", "🔥 哇塞！", "🎁 太棒了！", "🎊 手气不错！"]
    private let sadMessages = ["差一点就中了", "换个姿势再试", "大奖还在奖池里！", "别灰心，好运在后面", "换个手指再试一次？", "再接再厉哦"]
    
    // 跑马灯计时器
    private var rouletteTimer: Timer?

    init() { loadData() }
    
    func resetToNewRound() {
        self.activeMaxParticipants = configMaxParticipants
        self.activePrizes = configPrizes.map { Prize(id: $0.id, name: $0.name, count: $0.count, drawn: 0) }
        prizePool.removeAll()
        drawnCount = 0
        drawStatus = .idle
        showConfetti = false
        
        var totalPrizeCount = 0
        for prize in activePrizes {
            for _ in 0..<prize.count { prizePool.append(prize.id) }
            totalPrizeCount += prize.count
        }
        for _ in 0..<max(0, activeMaxParticipants - totalPrizeCount) { prizePool.append(nil) }
        prizePool.shuffle()
        currentResult = "奖池已重置"
        saveData()
    }
    
    func draw() {
        guard !prizePool.isEmpty, !isDrawing else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isDrawing = true
        drawStatus = .drawing
        showConfetti = false
        
        // 核心视觉冲击1：老虎机跑马灯效果
        let allNames = activePrizes.map { $0.name } + sadMessages
        rouletteTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.currentResult = allNames.randomElement() ?? "???"
            UIImpactFeedbackGenerator(style: .light).impactOccurred() // 哒哒哒的震感
        }
        
        // 1.5秒后揭晓
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.processDrawResult()
        }
    }
    
    private func processDrawResult() {
        rouletteTimer?.invalidate() // 停止跑马灯
        rouletteTimer = nil
        
        let drawnId = prizePool.removeLast()
        drawnCount += 1
        
        // 核心视觉冲击2：全屏爆闪
        withAnimation(.easeInOut(duration: 0.1)) { flashTrigger = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) { self.flashTrigger = false }
        }
        
        if let id = drawnId, let index = activePrizes.firstIndex(where: { $0.id == id }) {
            activePrizes[index].drawn += 1
            currentResult = "\(greetings.randomElement() ?? "")\n获得了【\(activePrizes[index].name)】"
            
            if index == 0 { drawStatus = .wonBig } else { drawStatus = .wonSmall }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showConfetti = true // 喷射礼花
            
        } else {
            currentResult = "\(sadMessages.randomElement() ?? "未中奖")"
            drawStatus = .missed
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        isDrawing = false
        saveData()
    }

    private func saveData() {
        UserDefaults.standard.set(activeMaxParticipants, forKey: "L_Max")
        UserDefaults.standard.set(drawnCount, forKey: "L_Drawn")
        if let prizesData = try? JSONEncoder().encode(activePrizes) { UserDefaults.standard.set(prizesData, forKey: "L_Prizes") }
        if let poolData = try? JSONEncoder().encode(prizePool) { UserDefaults.standard.set(poolData, forKey: "L_Pool") }
    }

    private func loadData() {
        let savedMax = UserDefaults.standard.integer(forKey: "L_Max")
        if savedMax == 0 { resetToNewRound(); return }
        activeMaxParticipants = savedMax
        drawnCount = UserDefaults.standard.integer(forKey: "L_Drawn")
        if let prizesData = UserDefaults.standard.data(forKey: "L_Prizes"), let prizes = try? JSONDecoder().decode([Prize].self, from: prizesData) { activePrizes = prizes }
        if let poolData = UserDefaults.standard.data(forKey: "L_Pool"), let pool = try? JSONDecoder().decode([UUID?].self, from: poolData) { prizePool = pool }
    }
}

// --- 3. 礼花粒子视图 ---
struct ConfettiView: View {
    @State private var particles: [Particle] = []
    let emojis = ["🎉", "✨", "💰", "🎊", "⭐", "💎"]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Text(particle.emoji)
                        .font(.system(size: 30 * particle.scale))
                        .rotationEffect(.degrees(particle.rotation))
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                for _ in 0..<40 {
                    let p = Particle(
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: -50, // 从屏幕顶部上方开始下落
                        rotation: Double.random(in: 0...360),
                        scale: CGFloat.random(in: 0.5...1.5),
                        emoji: emojis.randomElement()!
                    )
                    particles.append(p)
                }
                // 触发物理坠落动效
                withAnimation(.timingCurve(0.25, 1, 0.5, 1, duration: 2.5)) {
                    for i in 0..<particles.count {
                        particles[i].y = geo.size.height + 100 // 落到屏幕底部外
                        particles[i].rotation += Double.random(in: 180...720)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// --- 4. 主界面 ---
struct ContentView: View {
    @StateObject private var manager = LotteryManager()
    @State private var showSettings = false
    @State private var showStats = false
    @State private var breathingScale: CGFloat = 1.0
    
    var backgroundColors: [Color] {
        switch manager.drawStatus {
        case .idle: return [Color.blue.opacity(0.3), Color.purple.opacity(0.4)]
        case .drawing: return [Color.black.opacity(0.8), Color.purple.opacity(0.6)] // 抽取时变暗压抑
        case .wonBig: return [Color.yellow, Color.orange, Color.red] // 大奖高饱和
        case .wonSmall: return [Color.pink.opacity(0.8), Color.orange.opacity(0.8)]
        case .missed: return [Color.gray.opacity(0.8), Color.black.opacity(0.6)] // 没中奖冷色灰暗
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: backgroundColors), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.8), value: manager.drawStatus)
                
                // 礼花层
                if manager.showConfetti {
                    ConfettiView().id(UUID()) // 每次为true时重新生成
                }
                
                VStack {
                    Spacer()
                    
                    VStack(spacing: 50) {
                        // 结果文字区域：加入巨大的霓虹发光阴影
                        Text(manager.currentResult)
                            .font(.system(size: manager.drawStatus == .wonBig ? 42 : (manager.isDrawing ? 28 : 32), weight: .black, design: .rounded))
                            .foregroundColor(manager.drawStatus == .missed ? .white.opacity(0.5) : .white)
                            .multilineTextAlignment(.center)
                            .frame(height: 120)
                            .shadow(color: manager.drawStatus == .wonBig ? .yellow : .clear, radius: 20, x: 0, y: 0)
                            .scaleEffect(manager.drawStatus == .wonBig ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: manager.drawStatus)
                        
                        // 抽奖按钮
                        Button(action: manager.draw) {
                            Circle()
                                .fill(LinearGradient(colors: manager.isDrawing ? [.gray, .darkGray] : [.pink, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 200, height: 200)
                                .overlay(
                                    Text(manager.isDrawing ? "锁定中" : "抽 奖")
                                        .font(.system(size: 40, weight: .black))
                                        .foregroundColor(.white)
                                )
                                // 待机时的霓虹呼吸灯效
                                .shadow(color: manager.isDrawing ? .clear : .pink.opacity(0.8), radius: manager.isDrawing ? 0 : 30 * breathingScale, y: 10)
                        }
                        .disabled(manager.prizePool.isEmpty || manager.isDrawing)
                        .scaleEffect(manager.isDrawing ? 0.85 : breathingScale)
                        .animation(manager.isDrawing ? .easeIn(duration: 0.1) : .easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: breathingScale)
                        .onAppear { breathingScale = 1.05 }
                    }
                    
                    Spacer()
                    
                    // 隐藏统计面板 (逻辑同前版)
                    VStack {
                        Button(showStats ? "点击隐藏后台数据" : "⚙️ 展开实时数据") {
                            withAnimation(.spring()) { showStats.toggle() }
                        }
                        .font(.headline).foregroundColor(.white.opacity(0.7)).padding()
                        
                        if showStats {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(manager.activePrizes) { prize in
                                        let remain = prize.count - prize.drawn
                                        VStack {
                                            Text(prize.name).font(.caption).bold()
                                            Text("\(remain)").font(.title2).bold().foregroundColor(remain == 0 ? .red : .white)
                                        }
                                        .frame(width: 80).padding(.vertical, 10)
                                        .background(Color.black.opacity(0.4)).cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
                
                // 视觉炸裂的最强手段：全屏爆闪层放置在最顶层
                if manager.flashTrigger {
                    Color.white.ignoresSafeArea()
                        .transition(.opacity)
                }
            }
            .navigationBarHidden(true)
            // 将设置按钮挪到一个隐蔽的角落，保证画面纯净
            .overlay(
                Button(action: { showSettings = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.5))
                        .padding()
                }
                , alignment: .topTrailing
            )
            .sheet(isPresented: $showSettings) { SettingsView(manager: manager) }
        }
        .navigationViewStyle(.stack)
    }
}

// 定义一个颜色扩展，方便取暗灰色
extension Color { static let darkGray = Color(white: 0.3) }

// --- 5. 设置界面 (保持不变，省略了里面的具体内容以节省篇幅，直接用上一版即可) ---
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var manager: LotteryManager
    @State private var showConfirmReset = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("活动规则 (修改不影响当前轮次)")) {
                    HStack { Text("总参与人数"); Spacer(); TextField("", value: $manager.configMaxParticipants, formatter: NumberFormatter()).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80) }
                }
                Section(header: Text("奖项分配 (左滑可删除)")) {
                    ForEach($manager.configPrizes) { $prize in
                        HStack { TextField("奖项名称", text: $prize.name); Divider(); TextField("数量", value: $prize.count, formatter: NumberFormatter()).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 50); Text("个") }
                    }.onDelete { manager.configPrizes.remove(atOffsets: $0) }
                    Button { manager.configPrizes.append(Prize(name: "新增奖项", count: 1)) } label: { Label("添加奖项", systemImage: "plus.circle.fill") }
                }
                Section { Button(role: .destructive) { showConfirmReset = true } label: { HStack { Spacer(); Text("应用设置并重置奖池").fontWeight(.bold); Spacer() } } }
            }
            .navigationTitle("后台配置").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { presentationMode.wrappedValue.dismiss() } } }
            .alert("危险操作", isPresented: $showConfirmReset) {
                Button("强行重置", role: .destructive) { manager.resetToNewRound(); presentationMode.wrappedValue.dismiss() }
                Button("取消", role: .cancel) {}
            } message: { Text("清空当前记录并开启新轮次。") }
        }
    }
}