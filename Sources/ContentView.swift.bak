import SwiftUI
import UIKit
import AVFoundation
import AudioToolbox

// --- 1. 音效管理类 ---
class SoundManager {
    static let instance = SoundManager()
    var player: AVAudioPlayer?

    func playSound(named: String, systemSoundID: UInt32) {
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
    var x: CGFloat; var y: CGFloat; var rotation: Double; var scale: CGFloat; var emoji: String
}

// --- 3. 抽奖逻辑控制器 ---
class LotteryManager: ObservableObject {
    @Published var activeMaxParticipants: Int = 100
    @Published var activePrizes: [Prize] = []
    @Published var prizePool: [UUID?] = []
    @Published var drawnCount: Int = 0
    
    // 【修复核心1】：将单字符串拆分为标题和正文，彻底告别换行符带来的排版错乱
    @Published var resultTitle: String = " " 
    @Published var resultMessage: String = "点击开启好运"
    
    @Published var isDrawing: Bool = false
    @Published var drawStatus: DrawStatus = .idle
    @Published var showConfetti: Bool = false
    @Published var confettiCounter: Int = 0 
    
    @Published var configMaxParticipants: Int = 100
    @Published var configPrizes: [Prize] = []

    private let greetings = ["✨ 天呐！", "🎁 运气爆表！", "🔥 哇塞！", "🎁 太棒了！", "🎊 手气不错！", "🎉 恭喜"]
    private let sadMessages = ["差一点就中了", "换个姿势再试", "大奖还在奖池里！", "别灰心，好运在后面", "换个手指再试一次？", "与好运擦肩而过"]

    init() { loadData() }
    
    func draw() {
        guard !prizePool.isEmpty, !isDrawing else { return }
        
        SoundManager.instance.playSound(named: "draw", systemSoundID: 1104) 
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        isDrawing = true
        drawStatus = .drawing
        showConfetti = false
        
        // 抽取时清空副标题，只留正文
        resultTitle = " " 
        resultMessage = "凝聚好运中..." 
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.processDrawResult()
        }
    }
    
    private func processDrawResult() {
        let drawnId = prizePool.removeLast()
        drawnCount += 1
        
        if let id = drawnId, let index = activePrizes.firstIndex(where: { $0.id == id }) {
            activePrizes[index].drawn += 1
            
            // 分别赋值标题和正文
            resultTitle = greetings.randomElement() ?? "🎉"
            resultMessage = "获得了【\(activePrizes[index].name)】"
            
            if index == 0 { drawStatus = .wonBig } else { drawStatus = .wonSmall }
            SoundManager.instance.playSound(named: "win", systemSoundID: 1022)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showConfetti = true
            confettiCounter += 1
            
        } else {
            resultTitle = " " // 未中奖时隐藏标题（用空格占位防止高度塌陷）
            resultMessage = "\(sadMessages.randomElement() ?? "未中奖")"
            drawStatus = .missed
            SoundManager.instance.playSound(named: "fail", systemSoundID: 1053)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        isDrawing = false
        saveData()
    }

    func resetToNewRound() {
        self.activeMaxParticipants = configMaxParticipants
        self.activePrizes = configPrizes.map { Prize(id: $0.id, name: $0.name, count: $0.count, drawn: 0) }
        prizePool.removeAll()
        drawnCount = 0
        drawStatus = .idle
        showConfetti = false
        
        resultTitle = " "
        resultMessage = "奖池已重置"
        
        var totalPrizeCount = 0
        for prize in activePrizes {
            for _ in 0..<prize.count { prizePool.append(prize.id) }
            totalPrizeCount += prize.count
        }
        for _ in 0..<max(0, activeMaxParticipants - totalPrizeCount) { prizePool.append(nil) }
        prizePool.shuffle()
        saveData()
    }

    func saveConfig() {
        UserDefaults.standard.set(configMaxParticipants, forKey: "L_Config_Max")
        if let data = try? JSONEncoder().encode(configPrizes) { UserDefaults.standard.set(data, forKey: "L_Config_Prizes") }
    }

    private func saveData() {
        UserDefaults.standard.set(activeMaxParticipants, forKey: "L_Max")
        UserDefaults.standard.set(drawnCount, forKey: "L_Drawn")
        if let prizesData = try? JSONEncoder().encode(activePrizes) { UserDefaults.standard.set(prizesData, forKey: "L_Prizes") }
        if let poolData = try? JSONEncoder().encode(prizePool) { UserDefaults.standard.set(poolData, forKey: "L_Pool") }
    }

    private func loadData() {
        let savedConfigMax = UserDefaults.standard.integer(forKey: "L_Config_Max")
        if savedConfigMax > 0 { configMaxParticipants = savedConfigMax }
        if let data = UserDefaults.standard.data(forKey: "L_Config_Prizes"), let config = try? JSONDecoder().decode([Prize].self, from: data) {
            configPrizes = config
        } else {
            configPrizes = [Prize(name: "一等奖", count: 10), Prize(name: "二等奖", count: 10), Prize(name: "三等奖", count: 50)]
        }
        let savedMax = UserDefaults.standard.integer(forKey: "L_Max")
        if savedMax == 0 { resetToNewRound(); return }
        activeMaxParticipants = savedMax
        drawnCount = UserDefaults.standard.integer(forKey: "L_Drawn")
        if let prizesData = UserDefaults.standard.data(forKey: "L_Prizes"), let prizes = try? JSONDecoder().decode([Prize].self, from: prizesData) { activePrizes = prizes }
        if let poolData = UserDefaults.standard.data(forKey: "L_Pool"), let pool = try? JSONDecoder().decode([UUID?].self, from: poolData) { prizePool = pool }
    }
}

// --- 4. 礼花粒子视图 ---
struct ConfettiView: View {
    @State private var particles: [Particle] = []
    let emojis = ["🎉", "✨", "💫", "🎊", "⭐", "💎"]
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Text(particle.emoji).font(.system(size: 30 * particle.scale)).rotationEffect(.degrees(particle.rotation)).position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                for _ in 0..<45 {
                    particles.append(Particle(x: CGFloat.random(in: 0...geo.size.width), y: -50, rotation: Double.random(in: 0...360), scale: CGFloat.random(in: 0.5...1.5), emoji: emojis.randomElement()!))
                }
                withAnimation(.timingCurve(0.25, 1, 0.5, 1, duration: 2.8)) {
                    for i in 0..<particles.count {
                        particles[i].y = geo.size.height + 100
                        particles[i].rotation += Double.random(in: 180...720)
                    }
                }
            }
        }.allowsHitTesting(false)
    }
}

// --- 5. 主界面 ---
struct ContentView: View {
    @StateObject private var manager = LotteryManager()
    @State private var showSettings = false
    @State private var showStats = false
    @State private var breathingScale: CGFloat = 1.0
    
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
                
                if manager.showConfetti { ConfettiView().id(manager.confettiCounter) }
                
                VStack {
                    Spacer()
                    VStack(spacing: 50) { // 稍微缩小这里的间距
                        
                        // 【修复核心2】：分离标题与正文，并锁定死外层高度，彻底杜绝图层滑动与边缘裁剪
                        VStack(spacing: 12) {
                            Text(manager.resultTitle)
                                .font(.title2).bold()
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text(manager.resultMessage)
                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1) // 锁定单行
                                .minimumScaleFactor(0.4) // 自动缩放
                        }
                        .frame(height: 120) // 绝对锁死高度！再也不会上下乱跳了
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .shadow(color: manager.drawStatus == .wonBig ? .yellow.opacity(0.5) : .clear, radius: 20)
                        .blur(radius: manager.isDrawing ? 10 : 0)
                        .scaleEffect(manager.isDrawing ? 0.9 : (manager.drawStatus == .wonBig ? 1.15 : 1.0))
                        .animation(manager.isDrawing ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .spring(response: 0.4, dampingFraction: 0.6), value: manager.isDrawing)
                        
                        Button(action: manager.draw) {
                            Circle()
                                .fill(LinearGradient(colors: manager.isDrawing ? [Color.white.opacity(0.2), Color.white.opacity(0.1)] : [Color(red: 0.9, green: 0.4, blue: 0.5), Color(red: 0.9, green: 0.6, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 180, height: 180)
                                .overlay(
                                    Text(manager.isDrawing ? "凝聚中" : "抽 奖")
                                        .font(.system(size: 36, weight: .black))
                                        .foregroundColor(manager.isDrawing ? .white.opacity(0.5) : .white)
                                )
                                .shadow(color: manager.isDrawing ? .clear : Color.pink.opacity(0.5), radius: manager.isDrawing ? 0 : 20 * breathingScale, y: 10)
                        }
                        .disabled(manager.prizePool.isEmpty || manager.isDrawing)
                        .scaleEffect(manager.isDrawing ? 0.85 : (breathingScale))
                        .animation(manager.isDrawing ? .easeIn(duration: 0.1) : .easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: breathingScale)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { breathingScale = 1.04 }
                        }
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
                                .frame(minWidth: UIScreen.main.bounds.width - 40)
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
        .navigationViewStyle(.stack)
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
                Section(header: Text("基础设置"), footer: Text("修改后点击应用生效，App重启会记住此处的配置。")) {
                    HStack {
                        Text("总参与人数")
                        Spacer()
                        TextField("", value: $manager.configMaxParticipants, formatter: NumberFormatter()).keyboardType(.numberPad).multilineTextAlignment(.trailing).foregroundColor(.blue)
                    }
                }
                Section(header: Text("奖项分配")) {
                    ForEach($manager.configPrizes) { $prize in
                        HStack {
                            TextField("奖项名", text: $prize.name)
                            Spacer()
                            Stepper(value: $prize.count, in: 0...1000) {
                                Text("\(prize.count) 个").font(.system(.body, design: .monospaced)).foregroundColor(.secondary)
                            }.frame(maxWidth: 160)
                        }
                    }.onDelete { manager.configPrizes.remove(atOffsets: $0) }
                    Button { manager.configPrizes.append(Prize(name: "新奖项", count: 1)) } label: { Label("添加奖项", systemImage: "plus.circle.fill") }
                }
                Section { Button(role: .destructive) { showConfirmReset = true } label: { HStack { Spacer(); Text("强制重置当前奖池并应用新设置").fontWeight(.bold); Spacer() } } }
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