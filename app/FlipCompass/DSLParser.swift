import Foundation
import Yams

/// Yams → IR（强类型中间层）
/// 渲染管线：YAML 文本 → Yams → JSON-like → JSONDecoder → DSLPage IR
/// （IR 与组件注册表解耦，可单测/服务端可复用）
enum DSLParser {
    enum ParseError: Error, Equatable {
        case yamlSyntax(String)
        case manifestMissing
        case pageNotFound(String)
        case irDecode(String)
    }

    static func parseManifest(yaml: String) throws -> ModuleManifest {
        do {
            let node = try Yams.load(yaml: yaml)
            guard let dict = node as? [String: Any] else {
                throw ParseError.manifestMissing
            }
            let data = try JSONSerialization.data(withJSONObject: dict)
            do {
                return try JSONDecoder().decode(ModuleManifest.self, from: data)
            } catch {
                throw ParseError.irDecode(error.localizedDescription)
            }
        } catch let e as ParseError {
            throw e
        } catch {
            throw ParseError.yamlSyntax(error.localizedDescription)
        }
    }

    static func parsePage(yaml: String) throws -> DSLPage {
        do {
            let node = try Yams.load(yaml: yaml)
            guard let dict = node as? [String: Any] else {
                throw ParseError.pageNotFound("<empty>")
            }
            let data = try JSONSerialization.data(withJSONObject: dict)
            do {
                return try JSONDecoder().decode(DSLPage.self, from: data)
            } catch {
                throw ParseError.irDecode(error.localizedDescription)
            }
        } catch let e as ParseError {
            throw e
        } catch {
            throw ParseError.yamlSyntax(error.localizedDescription)
        }
    }

    static func parsePagesBundle(yamls: [String: String]) throws -> [String: DSLPage] {
        var out: [String: DSLPage] = [:]
        for (key, yaml) in yamls {
            out[key] = try parsePage(yaml: yaml)
        }
        return out
    }
}
