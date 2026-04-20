import SwiftUI

// --- 1. 数据模型 ---
struct Prize: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var count: Int
    var drawn: Int = 0 // 已抽出的数量
}

// --- 2. 抽奖逻辑控制器 ---
class LotteryManager: ObservableObject {
    @Published var maxParticipants: Int = 100
    // 默认奖项，现在支持动态修改了
    @Published var prizes: [Prize] = [
        Prize(name: "一等奖", count: 10),
        Prize(name: "二等奖", count: 10),
        Prize(name: "三等奖", count: 50)
    ]
    
    @Published var prizePool: [UUID?] = [] // UUID 代表对应奖项，nil 代表未中奖
    @Published var drawnCount: Int = 0
    @Published var currentResult: String = "点击下方按钮开始"
    @Published var showResultAnim: Bool = false
    
    // 初始化/重置奖池
    func setupPool() {
        prizePool.removeAll()
        drawnCount = 0
        
        // 重置所有奖项的已抽出数量
        for i in 0..<prizes.count { prizes[i].drawn = 0 }
        
        var totalPrizes = 0
        // 将奖项放入奖池
        for prize in prizes {
            for _ in 0..<prize.count {
                prizePool.append(prize.id)
            }
            totalPrizes += prize.count
        }
        
        // 计算未中奖的数量并放入奖池
        let noneCount = maxParticipants - totalPrizes
        for _ in 0..<max(0, noneCount) {
            prizePool.append(nil)
        }
        
        prizePool.shuffle() // 核心打乱逻辑
        currentResult = "奖池已更新，等待抽奖..."
        showResultAnim = false
    }
    
    // 抽奖动作
    func drawPrize() {
        guard !prizePool.isEmpty else {
            currentResult = "活动已结束！"
            return
        }
        
        // 触发 UI 动效
        withAnimation(.easeInOut(duration: 0.15)) { showResultAnim = true }
        
        let drawnId = prizePool.removeLast()
        drawnCount += 1
        
        if let id = drawnId, let index = prizes.firstIndex(where: { $0.id == id }) {
            prizes[index].drawn += 1
            currentResult = "🎉 恭喜获得：\(prizes[index].name)！"
        } else {
            currentResult = "🥺 很遗憾，本次未中奖"
        }
    }
}

// --- 3. 主界面 ---
struct ContentView: View {
    @StateObject private var manager = LotteryManager()
    @State private var showSettings = false
    
    // 适配动态数据的网格布局
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.15)]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // 中部：抽奖结果与按钮
                    VStack(spacing: 40) {
                        Text(manager.currentResult)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(manager.showResultAnim ? .primary : .secondary)
                            .multilineTextAlignment(.center)
                            .frame(height: 80)
                            .padding(.horizontal)
                        
                        Button(action: manager.drawPrize) {
                            Text("抽 奖")
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(.white)
                                .frame(width: 180, height: 180)
                                .background(
                                    Circle()
                                        .fill(LinearGradient(gradient: Gradient(colors: [Color.pink, Color.orange]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .shadow(color: .pink.opacity(0.4), radius: 15, x: 0, y: 15)
                                )
                        }
                        .disabled(manager.prizePool.isEmpty)
                        .scaleEffect(manager.prizePool.isEmpty ? 0.9 : 1.0)
                        .animation(.spring(), value: manager.prizePool.isEmpty)
                    }
                    
                    Spacer()
                    
                    // 底部：动态统计看板
                    VStack(spacing: 15) {
                        Text("抽奖进度: \(manager.drawnCount) / \(manager.maxParticipants)")
                            .font(.headline)
                        
                        Divider()
                        
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 15) {
                                ForEach(manager.prizes) { prize in
                                    VStack(spacing: 4) {
                                        Text(prize.name).font(.subheadline).bold().lineLimit(1)
                                        Text("已出: \(prize.drawn)").font(.caption).foregroundColor(.secondary)
                                        let remain = prize.count - prize.drawn
                                        Text("剩余: \(remain)").font(.caption).foregroundColor(remain == 0 ? .red : .green)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 150) // 限制高度，奖项过多时可滑动
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding()
                }
            }
            .navigationTitle("幸运抽奖")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 右上角齿轮图标
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primary)
                    }
                }
            }
            // 弹出设置页面
            .sheet(isPresented: $showSettings) {
                SettingsView(manager: manager)
            }
            .onAppear { manager.setupPool() }
        }
        // 确保在 iPad 上也只显示单列视图
        .navigationViewStyle(.stack) 
    }
}

// --- 4. 设置界面 ---
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var manager: LotteryManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基础设置"), footer: Text("修改参数后，关闭当前页面将自动重置抽奖进度。")) {
                    HStack {
                        Text("总人数上限")
                        Spacer()
                        TextField("例如: 100", value: $manager.maxParticipants, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("奖项管理 (左滑可删除)")) {
                    // 动态绑定奖项数组，支持修改名称和数量
                    ForEach($manager.prizes) { $prize in
                        HStack {
                            TextField("奖项名称", text: $prize.name)
                            Divider()
                            TextField("数量", value: $prize.count, formatter: NumberFormatter())
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("人")
                        }
                    }
                    .onDelete { indexSet in
                        manager.prizes.remove(atOffsets: indexSet)
                    }
                    
                    // 新增奖项按钮
                    Button(action: {
                        manager.prizes.append(Prize(name: "新增奖项", count: 1))
                    }) {
                        Label("添加新奖项", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("抽奖设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        // 关闭设置时，重新初始化奖池
                        manager.setupPool()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}