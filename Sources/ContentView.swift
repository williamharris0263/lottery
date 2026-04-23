import SwiftUI
import UIKit
import AVFoundation
import AudioToolbox

// --- 1. 音效管理类 ---
class SoundManager {
    static let instance = SoundManager()
    var player: AVAudioPlayer?

    // 播放系统内置音效或自定义 MP3 文件
    func playSound(named: String, systemSoundID: UInt32) {
        // 首先尝试播放 Sources 文件夹下的自定义 MP3
        if let path = Bundle.main.path(forResource: named, ofType: "mp3") {
            let url = URL(fileURLWithPath: path)
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player?.play()
                return 
            } catch {
                print("音频播放失败")
            }
        }
        // 如果没有自定义文件，则播放 iOS 系统内置音效 (作为兜底)
        AudioServicesPlaySystemSound(systemSoundID)
    }
}

// --- 2. 数据模型 ---
struct Prize: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var count: Int
    var drawn: Int = 0
}

enum DrawStatus {
    case idle, drawing, wonBig, wonSmall, missed
}

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var rotation: Double
    var scale: CGFloat
    var emoji: String
}

// --- 3. 抽奖逻辑控制器 ---
class LotteryManager: ObservableObject {
    @Published var activeMaxParticipants: Int = 100
    @Published var activePrizes: [Prize] = []
    @Published var prizePool: [UUID?] = []
    @Published var drawnCount: Int = 0
    
    @Published var resultTitle: String = " " 
    @Published var resultMessage: String = "点击开启好运"
    
    @Published var isDrawing: Bool = false
    @Published var drawStatus: DrawStatus = .idle
    @Published var showConfetti: Bool = false
    @Published var confettiCounter: Int = 0 
    
    // 配置态数据 (保证重启 App 不会丢失)
    @Published var configMaxParticipants: Int = 100
    @Published var configPrizes: [Prize] = [
        Prize(name: "一等奖", count: 10), 
        Prize(name: "二等奖", count: 10), 
        Prize(name: "三等奖", count: 50)
    ]

    // 随机文案库
    private let greetings = ["✨ 天呐！", "🎁 运气爆表！", "🔥 哇塞！", "🎁 太棒了！", "🎊 手气不错！", "🎉 恭喜"]
    private let sadMessages = ["差一点就中了", "换个姿势再试", "大奖还在奖池里！", "别灰心，好运在后面", "换个手指再试一次？", "与好运擦肩而过"]

    init() { 
	// 异步派发，先渲染UI
        DispatchQueue.main.async {
            self.loadData() 
        }
    }
    
    // 应用新设置，重置奖池并存档
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
        let noneCount = activeMaxParticipants - totalPrizeCount
        for _ in 0..<max(0, noneCount) { prizePool.append(nil) }
        prizePool.shuffle() // 洗牌
        currentResultTextUpdate(title: " ", message: "奖池已重置")
        saveData()
    }
    
    func draw() {
        guard !prizePool.isEmpty, !isDrawing else { return }
        
        SoundManager.instance.playSound(named: "draw", systemSoundID: 1104) 
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        isDrawing = true
        drawStatus = .drawing
        showConfetti = false
        resultTitle = "凝聚中..." 
        resultMessage = "凝聚中..." 
        
        // 1.5秒的高斯模糊凝聚期
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.processDrawResult()
        }
    }
    
    private func processDrawResult() {
        let drawnId = prizePool.removeLast()
        drawnCount += 1
        
        if let id = drawnId, let index = activePrizes.firstIndex(where: { $0.id == id }) {
            activePrizes[index].drawn += 1
            
            let prizeName = activePrizes[index].name
            let prefix = greetings.randomElement() ?? "🎉"
            
            currentResultTextUpdate(title: prefix, message: "获得了【\(prizeName)】")
            
            if index == 0 { drawStatus = .wonBig } else { drawStatus = .wonSmall }
            SoundManager.instance.playSound(named: "win", systemSoundID: 1022)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showConfetti = true
            confettiCounter += 1
            
        } else {
            let message = sadMessages.randomElement() ?? "未中奖"
            currentResultTextUpdate(title: " ", message: message)
            drawStatus = .missed
            SoundManager.instance.playSound(named: "fail", systemSoundID: 1053)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        isDrawing = false
        saveData()
    }
    
    private func currentResultTextUpdate(title: String, message: String) {
        resultTitle = title
        resultMessage = message
    }
    
    func saveConfig() {
        UserDefaults.standard.set(configMaxParticipants, forKey: "L_Config_Max")
        if let data = try? JSONEncoder().encode(configPrizes) { 
            UserDefaults.standard.set(data, forKey: "L_Config_Prizes") 
        }
    }
    
    // 持久化逻辑
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

// --- 4. 礼花粒子视图 (解决Uuid重绘坑) ---
struct ConfettiView: View {
    @State private var particles: [Particle] = []
    let emojis = ["🎉", "✨", "💫", "🎊", "⭐", "💎"]
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
                    particles.append(Particle(x: CGFloat.random(in: 0...geo.size.width), y: -50, rotation: Double.random(in: 0...360), scale: CGFloat.random(in: 0.5...1.5), emoji: emojis.randomElement()!))
                }
                withAnimation(.timingCurve(0.25, 1, 0.5, 1, duration: 2.5)) {
                    for i in 0..<particles.count {
                        particles[i].y = geo.size.height + 100
                        particles[i].rotation += Double.random(in: 180...720)
                    }
                }
            }
        }.allowsHitTesting(false)
    }
}

struct ContentView: View {
    @StateObject private var manager = LotteryManager()
    @State private var showSettings = false
    @State private var showStats = false
    @State private var breathingScale: CGFloat = 1.0
    
    // 莫兰迪高级流光配色回调
    var backgroundColors: [Color] {
        switch manager.drawStatus {
        case .idle: return [Color(red: 0.1, green: 0.2, blue: 0.5), Color(red: 0.3, green: 0.1, blue: 0.4)]
        case .drawing: return [Color.black.opacity(0.8), Color(red: 0.1, green: 0.1, blue: 0.3)]
        case .wonBig: return [Color.orange.opacity(0.8), Color.red.opacity(0.6)]
        case .wonSmall: return [Color.pink.opacity(0.6), Color.purple.opacity(0.6)]
        case .missed: return [Color.gray.opacity(0.5), Color(red: 0.1, green: 0.1, blue: 0.2)]
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: backgroundColors), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.2), value: manager.drawStatus)
                
                if manager.showConfetti {
                    // 绑定计数器作为 ID。展开统计面板不再误触发礼花。
                    ConfettiView().id(manager.confettiCounter) 
                }
                
                VStack {
                    Spacer()                
                    VStack(spacing: 14) { 
                        if !manager.resultTitle.isEmpty {
                            Text(manager.resultTitle)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .padding(.top, 20)
                                .layoutPriority(1)
                        }
                        
                        Text(manager.resultMessage)
                            .font(.system(size: 42, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .padding(.top, 40)
                    .blur(radius: manager.isDrawing ? 10 : 0)
                    .scaleEffect(manager.isDrawing ? 0.92 : 1)        
                    Spacer()
                        
                    // 经典粉橙呼吸按钮回调
                    Button(action: manager.draw) {
                        Circle()
                            .fill(LinearGradient(colors: manager.isDrawing ? [Color.white.opacity(0.2), Color.white.opacity(0.1)] : [Color(red: 0.9, green: 0.4, blue: 0.5), Color(red: 0.9, green: 0.6, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 180, height: 180)
                            .overlay(
                                Text(manager.isDrawing ? "凝聚中" : "抽 奖")
                                    .font(.system(size: 36, weight: .black))
                                    .foregroundColor(manager.isDrawing ? .white.opacity(0.5) : .white)
                            )
                            .shadow(color: manager.isDrawing ? .clear : Color.pink.opacity(0.6), radius: manager.isDrawing ? 0 : 30 * breathingScale, y: 10)
                    }
                    .disabled(manager.prizePool.isEmpty || manager.isDrawing)
                    .scaleEffect(manager.isDrawing ? 0.85 : (breathingScale * 0.95))
                    .animation(manager.isDrawing ? .easeIn(duration: 0.1) : .easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: breathingScale)
                    .onAppear {
                        // 延迟0.5秒等系统布局彻底死锁后再启动呼吸动效。
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { breathingScale = 1.15 }
                    }
                    
                    Spacer()
                    
                    VStack {
                        Button(action: { withAnimation(.spring()) { showStats.toggle() } }) {
                            Text(showStats ? "隐藏实时数据" : "⚙️ 展开实时数据")
                                .font(.subheadline).foregroundColor(.white.opacity(0.8))
                                .padding(.vertical, 8).padding(.horizontal, 16)
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                        if showStats {
                            ScrollView(.horizontal, showsIndicators: false) {
                                // 使用用 .frame(maxWidth: .infinity) 配合 Spacer 强制居中
                                HStack(spacing: 12) {
                                    Spacer(minLength: 0)
                                    ForEach(manager.activePrizes) { prize in
                                        let remain = prize.count - prize.drawn
                                        VStack(spacing: 4) {
                                            Text(prize.name).font(.caption).foregroundColor(.white.opacity(0.9))
                                            Text("\(remain)").font(.title3).bold().foregroundColor(remain == 0 ? .red.opacity(0.8) : .white)
                                        }
                                        .frame(width: 85).padding(.vertical, 12)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(16)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .frame(minWidth: UIScreen.main.bounds.width - 40) // 确保撑满宽度实现居中
                            }
                            .padding(.top, 10)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
            .overlay(
                Button(action: { showSettings = true }) {
                    Image(systemName: "slider.horizontal.3").font(.title2).foregroundColor(.white.opacity(0.6)).padding()
                }
                , alignment: .topTrailing
            )
            .sheet(isPresented: $showSettings) { SettingsView(manager: manager) }
        }
        .navigationViewStyle(.stack) // 确保 iPad 正常单列显示
    }
}

// --- 6. 设置界面 ---
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var manager: LotteryManager
    @State private var showConfirmReset = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("活动规则"), footer: Text("修改此处配置并在下次重置奖池时生效。")) {
                    HStack {
                        Text("总参与人数上限")
                        Spacer()
                        TextField("", value: $manager.configMaxParticipants, formatter: NumberFormatter()).keyboardType(.numberPad).multilineTextAlignment(.trailing).foregroundColor(.blue)
                    }
                }
                Section(header: Text("奖项分配")) {
                    ForEach($manager.configPrizes) { $prize in
                        HStack {
                            TextField("奖项名称", text: $prize.name)
                            Spacer()
                            // 用 Stepper 代替 TextField。光标更难点，手感更好且支持长按快速增减
                            Stepper(value: $prize.count, in: 0...1000) {
                                Text("\(prize.count) 个").font(.system(.body, design: .monospaced)).foregroundColor(.secondary)
                            }.frame(maxWidth: 160) // 限制宽度避免挤压名称
                        }
                    }.onDelete { manager.configPrizes.remove(atOffsets: $0) }
                    Button { manager.configPrizes.append(Prize(name: "新增奖项", count: 1)) } label: { Label("添加奖项", systemImage: "plus.circle.fill") }
                }
                Section { Button(role: .destructive) { showConfirmReset = true } label: { HStack { Spacer(); Text("应用设置并重置奖池").fontWeight(.bold); Spacer() } } }
            }
            .navigationTitle("后台配置").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { manager.saveConfig(); presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert("确认重置", isPresented: $showConfirmReset) {
                Button("确定重置", role: .destructive) { manager.saveConfig(); manager.resetToNewRound(); presentationMode.wrappedValue.dismiss() }
                Button("取消", role: .cancel) {}
            }
        }
    }
}