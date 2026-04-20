import SwiftUI

// --- 1. 数据模型 ---
struct Prize: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var count: Int
    var drawn: Int = 0
}

// --- 2. 抽奖逻辑控制器 ---
class LotteryManager: ObservableObject {
    // 【运行态】当前正在进行的抽奖数据
    @Published var activeMaxParticipants: Int = 100
    @Published var activePrizes: [Prize] = [
        Prize(name: "一等奖", count: 10),
        Prize(name: "二等奖", count: 10),
        Prize(name: "三等奖", count: 50)
    ]
    @Published var prizePool: [UUID?] = []
    @Published var drawnCount: Int = 0
    @Published var currentResult: String = "准备就绪"
    
    // 【配置态】用户在设置界面临时修改的数据
    @Published var configMaxParticipants: Int = 100
    @Published var configPrizes: [Prize] = [
        Prize(name: "一等奖", count: 10),
        Prize(name: "二等奖", count: 10),
        Prize(name: "三等奖", count: 50)
    ]

    init() {
        resetToNewRound()
    }
    
    // 核心逻辑：只有调用此方法，设置才会生效并重置进度
    func resetToNewRound() {
        // 1. 同步配置到运行态
        self.activeMaxParticipants = configMaxParticipants
        self.activePrizes = configPrizes.map { Prize(id: $0.id, name: $0.name, count: $0.count, drawn: 0) }
        
        // 2. 重新构建奖池
        prizePool.removeAll()
        drawnCount = 0
        
        var totalPrizeCount = 0
        for prize in activePrizes {
            for _ in 0..<prize.count {
                prizePool.append(prize.id)
            }
            totalPrizeCount += prize.count
        }
        
        let noneCount = activeMaxParticipants - totalPrizeCount
        for _ in 0..<max(0, noneCount) {
            prizePool.append(nil)
        }
        
        prizePool.shuffle()
        currentResult = "新一轮抽奖已开始"
    }
    
    func draw() {
        guard !prizePool.isEmpty else {
            currentResult = "本轮已结束"
            return
        }
        
        let drawnId = prizePool.removeLast()
        drawnCount += 1
        
        if let id = drawnId, let index = activePrizes.firstIndex(where: { $0.id == id }) {
            activePrizes[index].drawn += 1
            currentResult = "🎉 \(activePrizes[index].name)"
        } else {
            currentResult = "🥺 未中奖"
        }
    }
}

// --- 3. 主界面 ---
struct ContentView: View {
    @StateObject private var manager = LotteryManager()
    @State private var showSettings = false
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationView {
            VStack {
                // 结果显示区
                VStack(spacing: 20) {
                    Text(manager.currentResult)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .frame(height: 100)
                    
                    Button(action: manager.draw) {
                        Circle()
                            .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 200, height: 200)
                            .overlay(Text("抽奖").font(.system(size: 40, weight: .black)).foregroundColor(.white))
                            .shadow(radius: 10, y: 10)
                    }
                    .disabled(manager.prizePool.isEmpty)
                    .opacity(manager.prizePool.isEmpty ? 0.6 : 1.0)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // 统计区
                VStack(spacing: 15) {
                    HStack {
                        Text("进度: \(manager.drawnCount) / \(manager.activeMaxParticipants)")
                        Spacer()
                        if manager.prizePool.isEmpty {
                            Text("已结束").foregroundColor(.red).bold()
                        }
                    }
                    .font(.headline)
                    
                    Divider()
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(manager.activePrizes) { prize in
                                VStack {
                                    Text(prize.name).font(.caption).bold()
                                    Text("\(prize.count - prize.drawn)").font(.title3).bold().foregroundColor(.green)
                                    Text("剩余").font(.system(size: 10)).foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .frame(height: 160)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding()
            }
            .navigationTitle("幸运抽奖")
            .toolbar {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill").foregroundColor(.primary)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(manager: manager)
            }
        }
        .navigationViewStyle(.stack)
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
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                }
                
                Section(header: Text("奖项预设")) {
                    ForEach($manager.configPrizes) { $prize in
                        HStack {
                            TextField("奖项名", text: $prize.name)
                            TextField("数量", value: $prize.count, formatter: NumberFormatter())
                                .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 50)
                            Text("人")
                        }
                    }
                    .onDelete { manager.configPrizes.remove(atOffsets: $0) }
                    
                    Button { manager.configPrizes.append(Prize(name: "新奖项", count: 1)) } label: {
                        Label("添加奖项", systemImage: "plus.circle")
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showConfirmReset = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("立即应用设置并开启新一轮")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("抽奖配置")
            .toolbar {
                Button("关闭") { presentationMode.wrappedValue.dismiss() }
            }
            .alert("确认重置？", isPresented: $showConfirmReset) {
                Button("确定重置", role: .destructive) {
                    manager.resetToNewRound()
                    presentationMode.wrappedValue.dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("应用新设置将会清空当前所有抽奖进度，无法撤销。")
            }
        }
    }
}