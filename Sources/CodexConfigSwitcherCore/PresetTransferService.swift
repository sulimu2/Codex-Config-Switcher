import Foundation

public struct PresetTransferPayload: Codable, Equatable, Sendable {
    public var version: Int
    public var presets: [CodexPreset]

    public init(version: Int = 1, presets: [CodexPreset]) {
        self.version = version
        self.presets = presets
    }
}

public struct PresetTransferService {
    public init() {}

    public func exportPresets(_ presets: [CodexPreset]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(PresetTransferPayload(presets: presets))
    }

    public func importPresets(from data: Data) throws -> [CodexPreset] {
        let decoder = JSONDecoder()
        let jsonObject: Any

        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ConfigSwitchError.invalidFormat("导入文件不是合法的 JSON，请确认文件内容没有损坏。")
        }

        let importedPresets: [CodexPreset]

        if let dictionary = jsonObject as? [String: Any], dictionary["presets"] != nil {
            do {
                importedPresets = try decoder.decode(PresetTransferPayload.self, from: data).presets
            } catch {
                throw ConfigSwitchError.invalidFormat("导入文件包含 `presets` 字段，但内容无法解析为预设列表。")
            }
        } else if jsonObject is [[String: Any]] {
            do {
                importedPresets = try decoder.decode([CodexPreset].self, from: data)
            } catch {
                throw ConfigSwitchError.invalidFormat("导入文件看起来是预设数组，但其中有字段缺失或类型不正确。")
            }
        } else if jsonObject is [String: Any] {
            do {
                importedPresets = [try decoder.decode(CodexPreset.self, from: data)]
            } catch {
                throw ConfigSwitchError.invalidFormat("导入文件看起来是单个预设对象，但字段缺失或类型不正确。")
            }
        } else {
            throw ConfigSwitchError.invalidFormat("预设导入文件格式无效，必须是单个预设、预设数组，或带 version/presets 的导出文件。")
        }

        guard !importedPresets.isEmpty else {
            throw ConfigSwitchError.invalidFormat("导入文件中没有可用的预设。")
        }

        for (index, preset) in importedPresets.enumerated() {
            let validationResult = PresetValidator.validate(preset)
            if !validationResult.isValid {
                let presetName = preset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名预设" : preset.name
                let detail = validationResult.issues.map(\.message).joined(separator: "；")
                throw ConfigSwitchError.invalidFormat("第 \(index + 1) 个预设“\(presetName)”存在问题：\(detail)")
            }
        }

        return importedPresets
    }
}
