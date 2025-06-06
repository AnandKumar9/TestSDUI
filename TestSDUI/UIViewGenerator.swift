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

enum UIElementType: String, Decodable {
    case vstack = "VStack"
    case label = "Label"
    case button = "Button"
}

struct UIElementEssentials: Decodable {
    let type: UIElementType
    let description: String?
    let title: String?
    let action: String?
    let visibleIf: String?
    let children: [UIElementEssentials]?
}

// MARK: - Logic Engine Using JavaScriptCore
class JSEvaluator {
    private let jsContext: JSContext

    init(dataContext: [String: Any]) {
        self.jsContext = JSContext()!
        for (key, value) in dataContext {
            jsContext.setObject(value, forKeyedSubscript: key as (NSCopying & NSObjectProtocol))  // NOTE: JS happening here
        }
    }

    func evaluate(_ expression: String?) -> Bool {
        guard let expression = expression else { return true }
        return jsContext.evaluateScript(expression)?.toBool() ?? false  // NOTE: JS happening here
    }

    func interpolateDataIntoString(_ string: String?) -> String {
        guard let string = string else { return "" }
        
        // Regular expression for patterns such as `{{<anything in between>}}`
        let regex = try! NSRegularExpression(pattern: "\\{\\{(.*?)\\}\\}")
        let nsString = string as NSString
        let expectedJSScriptLocations = regex.matches(in: string, range: NSRange(location: 0, length: nsString.length))
        
        var interpolatedString: String = string
        for jsScriptLocation in expectedJSScriptLocations.reversed() {
            let jsScript = nsString.substring(with: jsScriptLocation.range(at: 1)).trimmingCharacters(in: .whitespaces)
            
//            print("Hi - \(nsString) - \(jsScript)")
            
            if let jsScriptOutput = jsContext.evaluateScript(jsScript)?.toString() { // NOTE: JS happening here
                print("Evaluates to - \(jsScriptOutput)")
                interpolatedString = (interpolatedString as NSString).replacingCharacters(in: jsScriptLocation.range, with: jsScriptOutput)
            }
        }
        return interpolatedString
    }
}

// MARK: - Renderer
class UIViewGenerator {
    var jsEvaluator: JSEvaluator
    var actions: [String: () -> Void] = [:]

    init(dataContext: [String: Any]) {
        self.jsEvaluator = JSEvaluator(dataContext: dataContext)
    }

    /*
     So for every type of UIElementEssentials, there are specific hard-coded things to do. For example,
     If its a VStack translate that to a UIStackView, and look at the children property to add arranged subviews.
     If its a label, translate that to a UILabel and get the text from text property but interpolate any necessary data context into it. Done by evaluating JS.
     If its a button, translate that to a UIButton and get the title once again from from text property but interpolate any necessary data context into it. Done by evaluating JS. The action however is lookedup in a native dictionary which holds all the actions.
     
     NOTE -
     While actions are still native so as to not have evaluatable JS as actions, evaluatable JS is coming elsewhere for rendering related information still.
     */
    func generateUIView(from elementEssentials: UIElementEssentials) -> UIView? {
        guard jsEvaluator.evaluate(elementEssentials.visibleIf) else { return nil }

        switch elementEssentials.type {
        case .vstack:
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.spacing = 12
            elementEssentials.children?.compactMap { generateUIView(from: $0) }.forEach(stackView.addArrangedSubview)
            return stackView

        case .label:
            let label = UILabel()
            label.text = jsEvaluator.interpolateDataIntoString(elementEssentials.description)
            label.numberOfLines = 0
            return label

        case .button:
            let button = UIButton(type: .system)
            button.setTitle(jsEvaluator.interpolateDataIntoString(elementEssentials.title), for: .normal)
            if let action = elementEssentials.action {
                button.addAction(UIAction { _ in self.actions[action]?() }, for: .touchUpInside) // TODO: What is happening here
            }
            return button
        }
    }
}

// MARK: - Example Usage (e.g., in ViewController)
func setupDemoUI(on view: UIView) {
    
    let layoutAPIResponsePayload = """
    {
      "type": "VStack",
      "children": [
        {
          "type": "Label",
          "description": "Welcome, {{username.toUpperCase()}}",
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

    // Convert API response payload to UIElementEssentials struct
    guard let data = layoutAPIResponsePayload.data(using: .utf8),
          let rootUIElementEssentials = try? JSONDecoder().decode(UIElementEssentials.self, from: data)
    else { return }

    /* Create a UIViewGenerator that has some data and actions attached to it.
     So its something that operates with some key-value pair data, which could be coming from API or elsewhere in the app. No matter how it comes though, the layout API should use the correct variable names.
     And it also has some action names. So as if what happens on tap of these actions is entirely native codebase. That executable JS is not coming from server.
     */
    let uiViewGenerator = UIViewGenerator(dataContext: ["username": "Anand"])
    uiViewGenerator.actions["greetAction"] = {
        print("Hello, Anand! 🎉")
    }

    // Use the above UIViewGenerator to take the UIElementEssentials and generate a UIView from it
    if let uiView = uiViewGenerator.generateUIView(from: rootUIElementEssentials) {
        uiView.frame = CGRect(x: 20, y: 100, width: view.bounds.width - 40, height: 200)
        view.addSubview(uiView)
    }
}

// Call `setupDemoUI(on: self.view)` from your ViewController to test.
