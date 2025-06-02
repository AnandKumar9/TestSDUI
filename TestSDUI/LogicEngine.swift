//
//  LogicEngine.swift
//  TestSDUI
//
//  Created by Anand Kumar on 5/31/25.
//

// TouchML-like JSON-driven UI with JavaScriptCore support

import UIKit
import JavaScriptCore

// MARK: - Element Model

enum ElementType: String, Decodable {
    case vstack = "VStack"
    case label = "Label"
    case button = "Button"
}

struct UIElement: Decodable {
    let type: ElementType
    let description: String?
    let title: String?
    let action: String?
    let visibleIf: String?
    let children: [UIElement]?
}

// MARK: - Logic Engine Using JavaScriptCore
class LogicEngine {
    private let context: JSContext

    init(data: [String: Any]) {
        self.context = JSContext()!
        for (key, value) in data {
            context.setObject(value, forKeyedSubscript: key as (NSCopying & NSObjectProtocol))
        }
    }

    func evaluate(_ expression: String?) -> Bool {
        guard let expression = expression else { return true }
        return context.evaluateScript(expression)?.toBool() ?? false
    }

    func interpolate(_ string: String?) -> String {
        guard let string = string else { return "" }
        let regex = try! NSRegularExpression(pattern: "\\{\\{(.*?)\\}\\}")  // \\{\\{(.*?)\\}\}
        let nsString = string as NSString
        let matches = regex.matches(in: string, range: NSRange(location: 0, length: nsString.length))
        var result = string
        for match in matches.reversed() {
            let expr = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            if let value = context.evaluateScript(expr)?.toString() {
                result = (result as NSString).replacingCharacters(in: match.range, with: value)
            }
        }
        return result
    }
}

// MARK: - Renderer
class TouchMLRenderer {
    var logicEngine: LogicEngine
    var actions: [String: () -> Void] = [:]

    init(dataContext: [String: Any]) {
        self.logicEngine = LogicEngine(data: dataContext)
    }

    func render(element: UIElement) -> UIView? {
        guard logicEngine.evaluate(element.visibleIf) else { return nil }

        switch element.type {
        case .vstack:
            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 12
            element.children?.compactMap { render(element: $0) }.forEach(stack.addArrangedSubview)
            return stack

        case .label:
            let label = UILabel()
            label.text = logicEngine.interpolate(element.description)
            label.numberOfLines = 0
            return label

        case .button:
            let button = UIButton(type: .system)
            button.setTitle(logicEngine.interpolate(element.title), for: .normal)
            if let action = element.action {
                button.addAction(UIAction { _ in self.actions[action]?() }, for: .touchUpInside)
            }
            return button
        }
    }
}

// MARK: - Example Usage (e.g., in ViewController)
func setupDemoUI(on view: UIView) {
    let jsonString = """
    {
      "type": "VStack",
      "children": [
        {
          "type": "Label",
          "description": "Welcome, {{username}}",
          "visibleIf": "username.length > 0"
        },
        {
          "type": "Button",
          "title": "Click to Greet",
          "action": "greetAction"
        }
      ]
    }
    """

    // Convert string to UIElement struct
    guard let data = jsonString.data(using: .utf8),
          let rootElement = try? JSONDecoder().decode(UIElement.self, from: data)
    else { return }

    // Generate a renderer that has some data attached to it
    let renderer = TouchMLRenderer(dataContext: ["username": "Anand"])
    renderer.actions["greetAction"] = {
        print("Hello, Anand! 🎉")
    }

    // Use the above renderer to take the above UIElement and generate a UIView from it
    if let renderedView = renderer.render(element: rootElement) {
        renderedView.frame = CGRect(x: 20, y: 100, width: view.bounds.width - 40, height: 200)
        view.addSubview(renderedView)
    }
}

// Call `setupDemoUI(on: self.view)` from your ViewController to test.
