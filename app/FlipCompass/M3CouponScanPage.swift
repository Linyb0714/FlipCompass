import SwiftUI
import PhotosUI
import Vision

// MARK: - d3′ · 截图导入券（C5+ 方案① · hero 卡片生长页）
//
// 流程：相册选券面截图 → Vision 本机识别（不上传）→ CouponScan 启发式解析 →
// 可编辑核对表单（标题/面额/门槛/有效期/门店）→ 保存入库 → p0 出现新券（未领取态）。
// 识别置信度不作硬保证——所有字段可改，剩余天数按有效期自动推算。

struct M3CouponScanPage: View {
    let onCancel: () -> Void
    /// 保存（父级入库 + toast + 收回）
    let onSave: (CouponDraft) -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var rawText = ""
    @State private var scanning = false

    @State private var title = ""
    @State private var value = ""
    @State private var threshold = ""
    @State private var valid = ""
    @State private var shopsText = ""

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 0) {
                    Text("截图导入券")
                        .font(DSToken.body(27, weight: .bold))
                        .foregroundStyle(DSToken.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)

                    Text("选券面截图 → 本机识别 → 核对保存")
                        .font(DSToken.body(12.5))
                        .foregroundStyle(DSToken.ink2)
                        .padding(.top, 8)

                    // ---- 截图选择 / 预览 ----
                    photoArea
                        .padding(.top, 22)

                    if scanning {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("正在本机识别…")
                                .font(DSToken.body(12.5))
                                .foregroundStyle(DSToken.ink2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 14)
                    }

                    if !rawText.isEmpty {
                        fieldLabel("识别结果核对", hint: "识别不准可手动改")
                            .padding(.top, 20)
                        editFields
                    }

                    saveButton
                        .padding(.top, 18)

                    HStack(spacing: 6) {
                        Text("✎")
                        Text("全程本机识别 · 图片与文字不上传任何服务器")
                    }
                    .font(DSToken.body(11))
                    .foregroundStyle(DSToken.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 9)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            HeroBackButton(title: "生活情报站", color: DSToken.m3) { onCancel() }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadImage(from: item) }
        }
    }

    // MARK: 选图区（虚线卡：未选 = 大按钮；已选 = 预览 + 重选）

    private var photoArea: some View {
        Group {
            if let image {
                VStack(spacing: 10) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 190)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
                    HStack {
                        Text("已识别 \(rawText.isEmpty ? "待" : "✓") · 换一张")
                            .font(DSToken.body(12, weight: .semibold))
                            .foregroundStyle(DSToken.m3)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(DSToken.m3.opacity(0.75))
                    Text("从相册选一张券面截图")
                        .font(DSToken.body(14, weight: .semibold))
                        .foregroundStyle(DSToken.ink2)
                    Text("美团 / 抖音 / 点评的券详情页截图都行")
                        .font(DSToken.body(11))
                        .foregroundStyle(DSToken.ink3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .overlay(
            RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                .strokeBorder(
                    image == nil ? DSToken.m3.opacity(0.5) : Color.clear,
                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                )
        )
        .background(
            RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                .fill(DSToken.m3.opacity(0.05))
        )
        .contentShape(RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous))
        .overlay {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Color.clear
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 字段编辑

    private var editFields: some View {
        VStack(spacing: 13) {
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("标题", hint: "必填")
                field("比如：奶茶买一送一", text: $title)
            }
            HStack(spacing: 13) {
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("面额", hint: "买一送一 / 减 5")
                    field("买一送一", text: $value)
                }
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("剩余天数", hint: valid.isEmpty ? "默认 7" : valid)
                    Text("\(CouponScan.daysLeft(valid: valid)) 天")
                        .font(DSToken.num(15, weight: .semibold))
                        .foregroundStyle(DSToken.m3)
                        .frame(height: 44, alignment: .center)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.92))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(DSToken.line, lineWidth: 1)
                        )
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("使用门槛", hint: "满 20 元可用")
                field("单笔满 20 元可用", text: $threshold)
            }
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("有效期", hint: "10-13 至 10-16")
                field("10-13 至 10-16", text: $valid)
            }
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("可用门店", hint: "一行一家")
                TextField("步行可达的那家：地铁 2 号线 · 1.1km", text: $shopsText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(DSToken.body(15.5))
                    .lineLimit(2...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(DSToken.line, lineWidth: 1)
                    )
            }
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("保存进生活情报站")
                .font(DSToken.body(16.5, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: DSToken.rCard, style: .continuous)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [DSToken.m3.mixedWithWhite(0.25), DSToken.m3]),
                                startPoint: UnitPoint(x: 0.5, y: 0), endPoint: UnitPoint(x: 0.33, y: 1)
                            )
                        )
                )
                .shadow(color: DSToken.m3.opacity(0.32), radius: 13, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.45)
        .animation(DSToken.spring, value: canSave)
    }

    // MARK: 动作

    private func loadImage(from item: PhotosPickerItem) async {
        scanning = true
        defer { scanning = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let ui = UIImage(data: data) else { return }
        image = ui
        let text = (try? await Self.recognize(ui)) ?? ""
        rawText = text
        guard !text.isEmpty else { return }
        let draft = CouponScan.parse(text)
        title = draft.title
        value = draft.value
        threshold = draft.threshold
        valid = draft.valid
        shopsText = draft.shops.joined(separator: "\n")
    }

    private func save() {
        var draft = CouponDraft()
        draft.title = title.trimmingCharacters(in: .whitespaces)
        draft.value = value.trimmingCharacters(in: .whitespaces)
        draft.threshold = threshold.trimmingCharacters(in: .whitespaces)
        draft.valid = valid.trimmingCharacters(in: .whitespaces)
        draft.daysLeft = CouponScan.daysLeft(valid: draft.valid)
        draft.shops = shopsText
            .split(whereSeparator: { $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        onSave(draft)
    }

    // MARK: Vision 本机识别（准确档 · 中英）

    static func recognize(_ image: UIImage) async throws -> String {
        guard let cg = image.cgImage else { return "" }
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hans_0", "zh-Hans_1", "en-US"]
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cg)
            try handler.perform([request])
            return request.results?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n") ?? ""
        }.value
    }

    // MARK: 小组件件

    private func fieldLabel(_ text: String, hint: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(DSToken.body(12, weight: .semibold))
                .foregroundStyle(DSToken.ink2)
                .tracking(0.5)
            Text(hint)
                .font(DSToken.body(10.5))
                .foregroundStyle(DSToken.ink3)
                .padding(.leading, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 2)
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(DSToken.body(15.5))
            .padding(.horizontal, 14)
            .frame(height: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(DSToken.line, lineWidth: 1)
            )
    }
}

// MARK: - 有效期反推剩余天数（表单公共入口；改了有效期也能对）

extension CouponScan {
    static func daysLeft(valid: String, now: Date = Date(), cal: Calendar = .current) -> Int {
        let (v, days) = extractValidity([valid], now: now, cal: cal)
        return v.isEmpty ? 7 : max(days, 0)
    }
}
