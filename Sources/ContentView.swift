import SwiftUI

// --- 1. 数据模型 ---
// 增加 Codable 协议，以便能够将数据转换为 JSON 保存到手机存储中
struct Prize: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var count: Int
    var drawn: Int = 0
}

// --- 2. 抽奖逻辑控制器 ---
class LotteryManager: ObservableObject {
    // --- 运行态数据 (当前正在进行的抽奖) ---
    @Published var activeMaxParticipants: Int = 100
    @Published var activePrizes: [Prize] = []
    @Published var prizePool: [UUID?] = []
    @Published var drawnCount: Int = 0
    @Published var currentResult: String = "准备就绪"
    
    // --- 配置态数据 (设置界面里调节的数值) ---
    @Published var configMaxParticipants: Int = 100
    @Published var configPrizes: [Prize] = [
        Prize(name: "一等奖", count: 1),
        Prize(name: "二等奖", count: 3),
        Prize(name: "三等奖", count: 10)
    ]

    // --- 个性化文案库 ---
    private let greetings = ["天呐！", "运气爆表！", "哇塞！", "太棒了！", "手气不错！"]
    private let sadMessages = ["差一点就中了", "再接再厉哦", "别灰心，好运在后面", "姿势不对，换个手指？"]

    init() {
        // App 启动时，尝试读取上次的进度
        loadData()
    }
    
    // --- 核心操作 ---
    // 应用新设置，重置奖池并保存
    func resetToNewRound() {
        // 将配置态同步到运行态
        self.activeMaxParticipants = configMaxParticipants
        self.activePrizes = configPrizes.map { Prize(id: $0.id, name: $0.name, count: $0.count, drawn: 0) }
        
        prizePool.removeAll()
        drawnCount = 0
        
        var totalPrizeCount = 0
        // 将所有奖项的“存货”打散成 UUID 放入奖池
        for prize in activePrizes {
            for _ in 0..<prize.count { prizePool.append(prize.id) }
            totalPrizeCount += prize.count
        }
        
        // 放入未中奖的名额 (用 nil 表示)
        let noneCount = activeMaxParticipants - totalPrizeCount
        for _ in 0..<max(0, noneCount) { prizePool.append(nil) }
        
        prizePool.shuffle() // 核心概率洗牌算法
        currentResult = "新一轮抽奖已开始"
        saveData() // 重置后立即存档
    }
    
    // 抽奖动作
    func draw() {
        guard !prizePool.isEmpty else { return }
        
        let drawnId = prizePool.removeLast()
        drawnCount += 1
        
        if let id = drawnId, let index = activePrizes.firstIndex(where: { $0.id == id }) {
            activePrizes[index].drawn += 1
            let prefix = greetings.randomElement() ?? ""
            currentResult = "\(prefix)获得了【\(activePrizes[index].name)】"
        } else {
            currentResult = sadMessages.randomElement() ?? "未中奖"
        }
        saveData() // 每次抽奖后存档
    }

    // --- 持久化系统 (UserDefaults) ---
    private func saveData() {
        UserDefaults.standard.set(activeMaxParticipants, forKey: "L_Max")
        UserDefaults.standard.set(drawnCount, forKey: "L_Drawn")
        
        if let prizesData = try? JSONEncoder().encode(activePrizes) {
            UserDefaults.standard.set(prizesData, forKey: "L_Prizes")
        }
        if let poolData = try? JSONEncoder().encode(prizePool) {
            UserDefaults.standard.set(poolData, forKey: "L_Pool")
        }
    }

    private func loadData() {
        let savedMax = UserDefaults.standard.integer(forKey: "L_Max")
        if savedMax == 0 {
            // 如果没读到数据（第一次打开App），则初始化
            resetToNewRound()
            return
        }
        
        activeMaxParticipants = savedMax
        drawnCount = UserDefaults.standard.integer(forKey: "L_Drawn")
        
        if let prizesData = UserDefaults.standard.data(forKey: "L_Prizes"),
           let prizes = try? JSONDecoder().decode([Prize].self, from: prizesData) {
            activePrizes = prizes
        }
        
        if let poolData = UserDefaults.standard.data(forKey: "L_Pool"),
           let pool = try? JSONDecoder().decode([UUID?].self, from: poolData) {
            prizePool = pool
        }
    }
}

// --- 3. 主界面 ---
struct ContentView: View {
    @StateObject private var manager = LotteryManager()
    @State private var showSettings = false
    @State private var showStats = false // 控制统计面板显隐的开关
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.15)]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // 中部区域：文字与大按钮
                    VStack(spacing: 30) {
                        Text(manager.currentResult)
                            .font(.title2).bold()
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .frame(height: 100)
                            .padding(.horizontal)
                        
                        Button(action: manager.draw) {
                            Circle()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 180, height: 180)
                                .overlay(Text("抽奖").font(.system(size: 36, weight: .black)).foregroundColor(.white))
                                .shadow(color: .purple.opacity(0.4), radius: 15, x: 0, y: 15)
                        }
                        .disabled(manager.prizePool.isEmpty)
                        .scaleEffect(manager.prizePool.isEmpty ? 0.9 : 1.0)
                        .animation(.spring(), value: manager.prizePool.isEmpty)
                    }
                    
                    Spacer()
                    
                    // 底部区域：统计数据面板
                    VStack(spacing: 15) {
                        HStack {
                            Text("当前进度").font(.headline)
                            Spacer()
                            Button(showStats ? "隐藏数据" : "点击查看数据") {
                                withAnimation { showStats.toggle() }
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        // 只有在 showStats 为 true 时才渲染具体数据
                        if showStats {
                            Divider()
                            HStack {
                                Text("已抽: \(manager.drawnCount)人")
                                Spacer()
                                Text("总容量: \(manager.activeMaxParticipants)人")
                            }
                            .font(.subheadline).foregroundColor(.secondary)
                            
                            // 奖项剩余情况（横向滚动，避免奖项过多挤压屏幕）
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(manager.activePrizes) { prize in
                                        VStack {
                                            Text(prize.name).font(.caption).bold().lineLimit(1)
                                            let remain = prize.count - prize.drawn
                                            Text("\(remain)").font(.title3).bold().foregroundColor(remain == 0 ? .red : .green)
                                            Text("剩余").font(.system(size: 10)).foregroundColor(.secondary)
                                        }
                                        .frame(width: 75)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.6))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .padding()
                }
            }
            .navigationTitle("幸运抽奖")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape.fill").foregroundColor(.primary) }
                }
            }
            // 弹出设置页
            .sheet(isPresented: $showSettings) { SettingsView(manager: manager) }
        }
        .navigationViewStyle(.stack) // 确保 iPad 也能正常单列显示
    }
}

// --- 4. 设置界面 ---
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var manager: LotteryManager
    @State private var showConfirmReset = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("参数调整 (不会立即影响当前抽奖)")) {
                    HStack {
                        Text("总人数上限")
                        Spacer()
                        TextField("", value: $manager.configMaxParticipants, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                
                Section(header: Text("奖项预设 (左滑删除)")) {
                    ForEach($manager.configPrizes) { $prize in
                        HStack {
                            TextField("奖项名", text: $prize.name)
                            Divider()
                            TextField("数量", value: $prize.count, formatter: NumberFormatter())
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                            Text("人")
                        }
                    }
                    .onDelete { manager.configPrizes.remove(atOffsets: $0) }
                    
                    Button { manager.configPrizes.append(Prize(name: "新奖项", count: 1)) } label: {
                        Label("添加新奖项", systemImage: "plus.circle.fill")
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showConfirmReset = true // 弹出危险操作确认框
                    } label: {
                        HStack {
                            Spacer()
                            Text("立即应用设置并开启新一轮")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("抽奖配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 点击关闭，什么都不发生，保留当前抽奖进度
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert("确认重置？", isPresented: $showConfirmReset) {
                Button("确定重置", role: .destructive) {
                    manager.resetToNewRound() // 真正执行重置
                    presentationMode.wrappedValue.dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("应用新设置将会清空当前所有抽奖进度，且无法撤销。")
            }
        }
    }
}