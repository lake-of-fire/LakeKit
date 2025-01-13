/*
import Foundation

// Forked from https://github.com/vapor-community/HTMLKit
public struct WebMinifier {
    
    public struct Compression: OptionSet {
        
        public var rawValue: Int
        
        public static let stripComments = Compression(rawValue: 1 << 0)
        public static let removeWhitespaces = Compression(rawValue: 1 << 1)
        public static let mangleVariables = Compression(rawValue: 1 << 2)
        public static let omitUnits = Compression(rawValue: 2 << 3)
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
    
    /// The level of compression
    private var compression: [Compression]
    
    /// Initiates a minifier
    public init(compression: [Compression]) {
        
        self.compression = compression
    }
    
    /// Minifies a stylesheet string
    public func minify(css content: String) -> String {
        
        var tokens = Stylesheet().consume(content)
        
        if compression.contains(.stripComments) {
            tokens.removeAll(where:  { $0 is Stylesheet.CommentToken })
        }
        
        var yield = [Token]()
        
        if compression.contains(.removeWhitespaces) {
            
            for (index, token) in tokens.enumerated() {
                
                if token is Stylesheet.WhitespaceToken {
                    
                    let previous = tokens.index(before: index)
                    let next = tokens.index(after: index)
                    
                    if previous >= tokens.startIndex && next < tokens.endIndex {
                        
                        // keep the whitespace if its between two selectors
                        if tokens[previous] is Stylesheet.SelectorToken && tokens[next] is Stylesheet.SelectorToken {
                            yield.append(token)
                        }
                        
                        // keep the whitespace if its between one selector and value token
                        if tokens[previous] is Stylesheet.SelectorToken && tokens[next] is Stylesheet.LiteralToken {
                            yield.append(token)
                        }
                        
                        // keep the whitespace if its between two value tokens
                        if tokens[previous] is Stylesheet.ValueToken && tokens[next] is Stylesheet.ValueToken {
                            yield.append(token)
                        }
                    }
                    
                } else {
                    yield.append(token)
                }
            }
        }
        
        return yield.map({ $0.present() }).joined()
    }
    
    /// Minifies a javascript string
    public func minify(js content: String) -> String {
        
        var tokens = Javascript().consume(content)
        
        if compression.contains(.stripComments) {
            tokens.removeAll(where:  { $0 is Javascript.CommentToken })
        }
        
        var yield = [Token]()
        
        if compression.contains(.removeWhitespaces) {
            
            for (index, token) in tokens.enumerated() {
                
                if token is Javascript.WhitespaceToken {
                    
                    let previous = tokens.index(before: index)
                    let next = tokens.index(after: index)
                    
                    if previous >= tokens.startIndex && next < tokens.endIndex {
                        
                        // keep the whitespace if its between two word tokens
                        if tokens[previous] is Javascript.WordToken && tokens[next] is Javascript.WordToken {
                            yield.append(token)
                        }
                    }
                    
                } else {
                    yield.append(token)
                }
            }
        }
        
        return yield.map({ $0.present() }).joined()
    }
}

internal class Stylesheet {
    
    /// A enumeration of different states of the minifier
    ///
    /// Code is the initial state.
    internal enum InsertionMode: String {
        
        case code
        case beforecomment
        case comment
        case aftercomment
        case selector
        case property
        case beforecustomproperty
        case customproperty
        case beforevalue
        case value
        case stringvalue
        case unidentified
        case afterunidentified
        case string
        case rule
        case argument
    }
    
    /// A enumeration of different level of the logging
    ///
    /// None is the initial state.
    internal enum LogLevel {
        
        case none
        case debug
    }
    
    /// The tree with nodes
    private var tokens: [Token]
    
    /// The temporary slot for a token
    private var token: Token?
    
    private var cache: String?
    
    /// The  state of the minifier
    private var mode: InsertionMode
    
    /// The level of logging
    private var level: LogLevel
    
    /// Creates a minifier
    internal init(mode: InsertionMode = .code, log level: LogLevel = .none) {
        
        self.tokens = []
        self.mode = mode
        self.level = level
    }
    
    /// Logs the steps of the minifier depending on the log level
    private func verbose(function: String, character: Character) {
        
        switch self.level {
            
        case .debug:
            
            if character.isNewline {
                print(function, "newline")
                
            } else if character.isWhitespace {
                print(function, "whitespace")
                
            } else {
                print(function, character)
            }
            
        default:
            break
        }
    }
    
    /// Caches the character for later
    private func cache(character: Character) {
        
        self.verbose(function: #function, character: " ")
        
        if var cache = self.cache {
            
            cache.append(character)
            
            self.cache = cache
            
        } else {
            self.cache = String(character)
        }
    }
    
    /// Clears the cache
    private func clear() -> String {
        
        self.verbose(function: #function, character: " ")
        
        guard let value = self.cache else {
            fatalError("Wait, there is nothing to clear")
        }
        
        self.cache = nil
        
        return value
    }
    
    /// Assigns a temporary token
    private func assign(token: Token) {
        
        self.verbose(function: #function, character: " ")
        
        if !(self.token?.value.isEmpty ?? true) {
            fatalError("Cannot assign the token. The previous token needs to be emitted first.")
        }
        
        self.token = token
    }
    
    /// Emits a token into the token collection
    private func emit(token: Token) {
        
        self.verbose(function: #function, character: " ")
        
        self.tokens.append(token)
    }
    
    /// Emits the temporary token into the token collection
    private func emit() {
        
        self.verbose(function: #function, character: " ")
        
        if let token = self.token {
            self.tokens.append(token)
        }
        
        self.token = nil
    }
    
    /// Collects the character for the token value
    private func collect(_ character: Character) {
        
        if var token = self.token {
            token.value.append(character)
        }
    }
    
    /// Consumes the content by the state the minifier is currently in
    public func consume(_ content: String) -> [Token] {
        
        for character in content.enumerated() {
            
            switch self.mode {
                
            case .beforecomment:
                self.mode = consumeBeforeComment(character.element)
                
            case .comment:
                self.mode = consumeComment(character.element)
                
            case .aftercomment:
                self.mode = consumeAfterComment(character.element)
                
            case .selector:
                self.mode = consumeSelector(character.element)
                
            case .property:
                self.mode = consumeProperty(character.element)
                
            case .beforecustomproperty:
                self.mode = consumeBeforeCustomProperty(character.element)
                
            case .customproperty:
                self.mode = consumeCustomProperty(character.element)
                
            case .beforevalue:
                self.mode = consumeBeforeValue(character.element)
                
            case .value:
                self.mode = consumeValue(character.element)
                
            case .stringvalue:
                self.mode = consumeStringValue(character.element)
                
            case .unidentified:
                self.mode = consumeUnkown(character.element)
                
            case .afterunidentified:
                self.mode = consumeAfterUnkown(character.element)
                
            case .string:
                self.mode = consumeStringLiteral(character.element)
                
            case .rule:
                self.mode = consumeRule(character.element)
                
            case .argument:
                self.mode = consumeArgument(character.element)
                
            default:
                self.mode = consumeCode(character.element)
            }
        }
        
        return tokens
    }
    
    /// Consumes the character
    internal func consumeCode(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isNewline {
            
            self.emit(token: WhitespaceToken(type: .return ,value: String(character)))
            
            return .code
        }
        
        if character.isWhitespace {
            
            self.emit(token: WhitespaceToken(type: .whitespace, value: String(character)))
            
            return .code
        }
        
        if character.isSolidus {
            // ignore character
            return .beforecomment
        }
        
        if character.isPeriod {
            
            self.assign(token: SelectorToken(type: .class, value: ""))
            
            return .selector
        }
        
        if character.isColon {
            
            self.assign(token: SelectorToken(type: .root, value: ""))
            
            return .selector
        }
        
        if character.isNumberSign {
            
            self.assign(token: SelectorToken(type: .id, value: ""))
            
            return .selector
        }
        
        if character.isLetter {
            
            let leftCurlyBrackets = self.tokens.filter({ $0.value == "{" })
            let rightCurlyBrackets = self.tokens.filter({ $0.value == "}" })
            
            if leftCurlyBrackets.count != rightCurlyBrackets.count {
                
                self.cache(character: character)
                
                return .unidentified
            }
            
            self.assign(token: SelectorToken(type: .type, value: String(character)))
            
            return .selector
        }
        
        if character.isQuotationMark {
            
            self.assign(token: LiteralToken(value: ""))
            
            return .string
        }
        
        if character.isCommercialAt {
            
            self.assign(token: SelectorToken(type: .rule, value: ""))
            
            return .selector
        }
        
        if character.isHyphenMinus {
            // ignore character
            return .beforecustomproperty
        }
        
        if character.isLeftParenthesis {
            
            self.emit(token: FormatToken(type: .punctuator, value: String(character)))
            
            self.assign(token: RuleToken(value: ""))
            
            return .rule
        }
        
        if character.isLeftCurlyBracket || character.isRightCurlyBracket || character.isComma {
            
            self.emit(token: FormatToken(type: .punctuator, value: String(character)))
            
            return .code
        }
        
        if character.isLeftSquareBracket {
            
            self.assign(token: SelectorToken(type: .attribute, value: String(character)))
            
            return .selector
        }
        
        if character.isOperator {
            
            self.emit(token: FormatToken(type: .operator, value: String(character)))
            
            return .code
        }
        
        return .code
    }
    
    /// Consumes the character before the comment
    internal func consumeBeforeComment(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isSolidus {
            
            self.assign(token: CommentToken(type: .line, value: ""))
            
            // ignore character
            return .comment
        }
        
        if character.isAsterisk {
            
            self.assign(token: CommentToken(type: .block, value: ""))
            
            // ignore character
            return .comment
        }
        
        // ignore character
        return .beforecomment
    }
    
    /// Consumes the character of a comment
    ///
    /// ```css
    /// /* comment */
    /// ```
    internal func consumeComment(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isAsterisk {
            
            self.emit()
            
            return .aftercomment
        }
        
        self.collect(character)
        
        return .comment
    }
    
    /// Consumes the character after a comment
    internal func consumeAfterComment(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isSolidus {
            
            return .code
        }
        
        // ignore character
        return .aftercomment
    }
    
    /// Consumes a selector
    ///
    /// ```css
    /// .selector {
    /// }
    /// ```
    internal func consumeSelector(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isLeftCurlyBracket {
            
            self.emit()
            
            self.emit(token: FormatToken(type: .punctuator, value: String(character)))
            
            return .code
        }
        
        if character.isWhitespace {
            
            self.emit()
            
            self.emit(token: WhitespaceToken(type: .whitespace, value: ""))
            
            return .code
        }
        
        self.collect(character)
        
        return .selector
    }
    
    /// Consumes the character of a property
    ///
    /// ```css
    /// property: value;
    /// ```
    internal func consumeProperty(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isWhitespace {
            
            self.emit(token: WhitespaceToken(type: .whitespace, value: ""))
            
            return .property
        }
        
        if character.isColon {
            
            self.emit()
            
            self.emit(token: FormatToken(type: .punctuator, value: String(character)))
            
            return .beforevalue
        }
        
        self.collect(character)
        
        return .property
    }
    
    /// Consumes a character before a custom property
    internal func consumeBeforeCustomProperty(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isHyphenMinus {
            
            self.assign(token: PropertyToken(type: .custom, value: ""))
            
            return .customproperty
        }
        
        if character.isLetter {
            
            self.assign(token: PropertyToken(type: .browser, value: String(character)))
            
            return .property
        }
        
        return .beforecustomproperty
    }
    
    /// Consumes a character of a custom property
    ///
    /// ```css
    /// --customproperty; value;
    /// ```
    internal func consumeCustomProperty(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isWhitespace {
            
            self.emit(token: WhitespaceToken(type: .whitespace, value: ""))
            
            return .customproperty
        }
        
        if character.isColon {
            
            self.emit()
            
            self.emit(token: FormatToken(type: .punctuator, value: String(character)))
            
            return .beforevalue
        }
        
        self.collect(character)
        
        return .customproperty
    }
    
    /// Consumes the character in front of a value
    internal func consumeBeforeValue(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isSemicolon {
            
            self.emit()
            
            self.emit(token: FormatToken(type: .terminator, value: String(character)))
            
            return .code
        }
        
        if character.isQuotationMark {
            
            self.assign(token: ValueToken(type: .string, value: ""))
            
            return .stringvalue
        }
        
        if character.isNumber || character.isHyphenMinus {
            
            self.assign(token: ValueToken(type: .numeric, value: String(character)))
            
            return .value
        }
        
        if character.isLetter {
            
            self.assign(token: ValueToken(type: .keyword, value: String(character)))
            
            return .value
        }
        
        if character.isExclamationMark {
            
            self.assign(token: ValueToken(type: .rule, value: String(character)))
            
            return .value
        }
        
        if character.isComma || character.isSolidus {
            
            self.emit(token: FormatToken(type: .terminator, value: String(character)))
            
            return .beforevalue
        }
        
        return .beforevalue
    }
    
    /// Consumes the character of a value
    ///
    /// ```css
    /// property: value;
    /// ```
    internal func consumeValue(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isSemicolon {
            
            self.emit()
            
            self.emit(token: FormatToken(type: .terminator, value: String(character)))
            
            return .code
        }
        
        if character.isLeftParenthesis {
            
            self.emit()
            
            self.emit(token: FormatToken(type: .parenthesis, value: String(character)))
            
            self.assign(token: ValueToken(type: .function, value: ""))
            
            return .argument
        }
        
        if character.isWhitespace {
            
            self.emit()
            
            self.emit(token: WhitespaceToken(type: .whitespace, value: String(character)))
            
            return .beforevalue
        }
        
        if character.isComma {
            
            self.emit()
            
            self.emit(token: FormatToken(type: .terminator, value: String(character)))
            
            return .beforevalue
        }
        
        self.collect(character)
        
        return .value
    }
    
    /// Consumes a character of a string value
    internal func consumeStringValue(_ character: Character) -> InsertionMode {
        
        if character.isQuotationMark {
            
            self.emit()
            
            return .value
        }
        
        self.collect(character)
        
        return .stringvalue
    }
    
    /// Consumes a unidentified character sequence
    internal func consumeUnkown(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isColon {
            
            self.cache(character: character)
            
            return .afterunidentified
        }
        
        if character.isWhitespace || character.isLeftCurlyBracket {
            
            self.emit(token: SelectorToken(type: .type, value: clear()))
            
            self.emit(token: WhitespaceToken(type: .whitespace, value: ""))
            
            return .code
        }
        
        self.cache(character: character)
        
        return .unidentified
    }
    
    func consumeAfterUnkown(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        // its a property
        if character.isWhitespace {
            
            var cache = clear()
            
            // since we know its property now, take the colon
            let colon: Character = cache.removeLast()
            
            self.emit(token: PropertyToken(type: .regular, value: cache))
            
            self.emit(token: FormatToken(type: .terminator, value: String(colon)))
            
            return .beforevalue
        }
        
        // its a pseudo element
        if character.isColon {
            
            self.cache(character: character)
            
            return .unidentified
        }
        
        // its a pseudo selector
        if character.isLetter {
            
            self.cache(character: character)
            
            return .unidentified
        }
        
        return .afterunidentified
    }
    
    /// Consumes a chracter for a string literal
    ///
    /// ```css
    /// "string"
    /// ```
    ///
    internal func consumeStringLiteral(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isQuotationMark {
            
            self.emit()
            
            return .code
        }
        
        self.collect(character)
        
        return .string
    }
    
    /// Consumes a character for a rule selector
    ///
    /// ```css
    /// @rule {
    /// }
    /// ```
    internal func consumeRule(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isRightParenthesis {
            
            self.emit()
            
            self.emit(token: FormatToken(type: .punctuator, value: String(character)))
            
            return .code
        }
        
        self.collect(character)
        
        return .rule
    }
    
    /// Consumes a character of an function argument
    ///
    /// ```css
    /// function(argument);
    /// ```
    internal func consumeArgument(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isRightParenthesis {
            
            let leftParenthesis = self.tokens.filter({ $0.value == "(" })
            let rightParenthesis = self.tokens.filter({ $0.value == ")" })
            
            if (rightParenthesis.count + 1) != leftParenthesis.count {
                
                self.emit()
                
                self.emit(token: FormatToken(type: .parenthesis, value: String(character)))
                
                self.assign(token: ValueToken(type: .function, value: ""))
                
                return .argument
            }
            
            self.emit()
            
            self.emit(token: FormatToken(type: .parenthesis, value: String(character)))
            
            return .beforevalue
        }
        
        if character.isLeftParenthesis {
            
            self.emit()
            
            self.emit(token: FormatToken(type: .parenthesis, value: String(character)))
            
            self.assign(token: ValueToken(type: .function, value: ""))
            
            return .argument
        }
        
        self.collect(character)
        
        return .argument
    }
}

extension Stylesheet {
    
    internal class WhitespaceToken: Token {
        
        /// A enumeration of the variations of comment tokens
        internal enum TokenType {
            
            /// Indicates a single line comment
            case whitespace
            
            /// Indicates a multiline comment
            case `return`
        }
        
        /// The type of the token
        internal var type: TokenType
        
        /// The value of the token
        internal var value: String
        
        /// Initiates a comment token
        internal init(type: TokenType, value: String) {
            
            self.type = type
            self.value = value
        }
        
        internal func present() -> String {
            
            switch type {
            case .return:
                return "\r\n"
                
            case .whitespace:
                return " "
            }
        }
    }
    
    /// A type that represents a css comment
    internal class CommentToken: Token {
        
        /// A enumeration of the variations of comment tokens
        internal enum TokenType {
            
            /// Indicates a single line comment
            case line
            
            /// Indicates a multiline comment
            case block
        }
        
        /// The type of the token
        internal var type: TokenType
        
        /// The value of the token
        internal var value: String
        
        /// Initiates a comment token
        internal init(type: TokenType, value: String) {
            
            self.type = type
            self.value = value
        }
        
        /// Minifies a comment token
        internal func present() -> String {
            
            switch type {
            case .line:
                return "//\(value)"
                
            case .block:
                return "/*\(value)*/"
            }
        }
    }
    
    /// A type that represents a css comment
    internal class SelectorToken: Token {
        
        /// A enumeration of the variations of comment tokens
        internal enum TokenType {
            
            /// Indicates the set is about an type
            case type
            
            /// Indicates the set is about a class
            case `class`
            
            /// Indicates the set is about a id
            case id
            
            /// Indicates the set is about a root
            case root
            
            /// Indicates a universal selector
            case universal
            
            /// Indicates a attribute selector
            case attribute
            
            /// Indicates a rule selector
            case rule
        }
        
        /// The type of the token
        internal var type: TokenType
        
        /// The value of the token
        internal var value: String
        
        /// Initiates a comment token
        internal init(type: TokenType, value: String) {
            
            self.type = type
            self.value = value
        }
        
        /// Minifies a comment token
        internal func present() -> String {
            
            switch type {
            case .type:
                return "\(value)"
                
            case .class:
                return ".\(value)"
                
            case .id:
                return "#\(value)"
                
            case .root:
                return ":\(value)"
                
            case .universal:
                return value
                
            case .attribute:
                return value
                
            case .rule:
                return "@\(value)"
            }
        }
    }
    
    /// A type that represents a format control token
    internal class FormatToken: Token {
        
        /// A enumeration of the variation of format tokens
        internal enum TokenType {
            
            /// Indicates a punctiation
            case punctuator
            
            /// Indicates a line terminator character
            case terminator
            
            /// Indicates a line operator character
            case `operator`
            
            /// Indicates a parenthesis
            case parenthesis
        }
        
        /// The type of the token
        internal var type: TokenType
        
        /// The value of the token
        internal var value: String
        
        /// Initiates a format token
        internal init(type: TokenType, value: String) {
            
            self.type = type
            self.value = value
        }
        
        /// Minifies a format token
        internal func present() -> String {
            return value
        }
    }
    
    /// A type that represents a format control token
    internal class PropertyToken: Token {
        
        /// A enumeration of the variation of format tokens
        internal enum TokenType {
            
            /// Indicates a regular property
            case regular
            
            /// Indicates a custom property
            case custom
            
            /// Indicates a browser property
            case browser
        }
        
        /// The type of the token
        internal var type: TokenType
        
        /// The value of the token
        internal var value: String
        
        /// Initiates a format token
        internal init(type: TokenType, value: String) {
            
            self.type = type
            self.value = value
        }
        
        /// Minifies a format token
        internal func present() -> String {
            
            switch type {
            case .regular:
                return "\(value)"
                
            case .browser:
                return "-\(value)"
                
            case .custom:
                return "--\(value)"
            }
        }
    }
    
    /// A type that represents a format control token
    internal class ValueToken: Token {
        
        /// A enumeration of the variation of format tokens
        internal enum TokenType {
            
            /// Indicates a punctiation
            case keyword
            
            /// Indicates a line terminator character
            case numeric
            
            /// Indicates a function
            case function
            
            /// Indicates a string
            case string
            
            /// indicates a rule
            case rule
        }
        
        /// The type of the token
        internal var type: TokenType
        
        /// The value of the token
        internal var value: String
        
        /// Initiates a format token
        internal init(type: TokenType, value: String) {
            
            self.type = type
            self.value = value
        }
        
        /// Minifies a format token
        internal func present() -> String {
            
            switch type {
            case .string:
                return "\"\(value)\""
                
            default:
                return value
            }
        }
    }
    
    internal class LiteralToken: Token {
        
        internal var value: String
        
        internal init(value: String) {
            self.value = value
        }
        
        internal func present() -> String {
            return "\"\(value)\""
        }
    }
    
    internal class RuleToken: Token {
        
        internal var value: String
        
        internal init(value: String) {
            self.value = value
        }
        
        internal func present() -> String {
            return value
        }
    }
}

/// A Type that represents a javascript token
internal protocol Token {
    
    var value: String { get set }
    
    func present() -> String
}

extension Character {
    
    /// A boolean value indicating whether this character represents an ampersand (U+0026).
    public var isAmpersand: Bool {
        
        if self == "\u{0026}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a question mark (U+003F).
    public var isQuestionMark: Bool {
        
        if self == "\u{003F}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a greater-than sign (U+003E).
    public var isGreaterThanSign: Bool {
        
        if self == "\u{003E}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a less-than sign (U+003C).
    public var isLessThanSign: Bool {
        
        if self == "\u{003C}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a solidus (U+002F).
    public var isSolidus: Bool {
        
        if self == "\u{002F}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents an exclamation mark (U+0021).
    public var isExclamationMark: Bool {
        
        if self == "\u{0021}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents an equal sign (U+003D).
    public var isEqualSign: Bool {
        
        if self == "\u{003D}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents an apostrophe (U+0027).
    public var isApostrophe: Bool {
        
        if self == "\u{0027}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents an quotation mark (U+0022)
    public var isQuotationMark: Bool {
        
        if self == "\u{0022}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents an hyphen minus (U+002D).
    public var isHyphenMinus: Bool {
        
        if self == "\u{002D}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a number sign (U+0023).
    public var isNumberSign: Bool {
        
        if self == "\u{0023}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents an asterisk (U+002A).
    public var isAsterisk: Bool {
        
        if self == "\u{002A}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a back tick (U+0060).
    public var isBackTick: Bool {
        
        if self == "\u{0060}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a colon (U+003A)
    public var isColon: Bool {
        
        if self == "\u{003A}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a semicolon (U+003B)
    public var isSemicolon: Bool {
        
        if self == "\u{003B}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a period (U+002E).
    public var isPeriod: Bool {
        
        if self == "\u{002E}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a comma (U+002C)
    public var isComma: Bool {
        
        if self == "\u{002C}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a comma (U+0040)
    public var isCommercialAt: Bool {
        
        if self == "\u{0040}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a comma (U+0024)
    public var isDollarSign: Bool {
        
        if self == "\u{0024}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a comma (U+005F)
    public var isUnderscore: Bool {
        
        if self == "\u{005F}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a comma (U+0028)
    public var isLeftParenthesis: Bool {
        
        if self == "\u{0028}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a comma (U+0029)
    public var isRightParenthesis: Bool {
        
        if self == "\u{0029}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a comma (U+007B)
    public var isLeftCurlyBracket: Bool {
        
        if self == "\u{007B}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a comma (U+007D)
    public var isRightCurlyBracket: Bool {
        
        if self == "\u{007D}" {
            return true
        }
        
        return false
    }
    
    public var isLeftSquareBracket: Bool {
        
        if self == "\u{005B}" {
            return true
        }
        
        return false
    }
    
    public var isRightSquareBracket: Bool {
        
        if self == "\u{005D}" {
            return true
        }
        
        return false
    }
    
    public var isPipe: Bool {
        
        if self == "\u{007C}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a bracket.
    ///
    /// For example, the following characters all represent brackets:
    ///
    /// - "(" (U+0028 LEFT PARENTHESIS)
    /// - ")" (U+0029 RIGHT PARENTHESIS)
    /// - "{" (U+007B LEFT CURLY BRACKET)
    /// - "}" (U+007D RIGHT CURLY BRACKET)
    /// - "[" (U+005B LEFT SQUARE BRACKET)
    /// - "]" (U+005D RIGHT SQUARE BRACKET)
    public var isBracket: Bool {
        
        if self == "\u{0028}" || self == "\u{0029}" || self == "\u{007B}" || self == "\u{007D}" || self == "\u{005B}" || self == "\u{005D}" {
            return true
        }
        
        return false
    }
    
    /// A boolean value indicating whether this character represents a operator.
    ///
    /// For example, the following characters all represent brackets:
    ///
    /// - "<" (U+003C LESS-THAN SIGN)
    /// - ">" (U+003E GREATER-THAN SIGN
    /// - "+" (U+002B PLUS SIGN)
    /// - "-" (U+2212 MINUS SIGN)
    /// - "\*" (U+002A ASTERSIK SIGN)
    public var isOperator: Bool {
        
        if self == "\u{003C}" || self == "\u{003E}" || self == "\u{002B}" || self == "\u{002D}" || self == "\u{002A}" || self == "\u{007E}" {
            return true
        }
        
        return false
    }
}

internal class Javascript {
    
    /// A enumeration of different states of the minifier
    ///
    /// Code is the initial state.
    internal enum InsertionMode: String {
        
        case code
        case beforecomment
        case linecomment
        case blockcomment
        case hashbang
        case aftercomment
        case word
        case string
        case template
        case numeric
    }
    
    /// A enumeration of different level of the logging
    ///
    /// None is the initial state.
    internal enum LogLevel {
        
        case none
        case debug
    }
    
    /// The token collection
    private var tokens: [Token]
    
    /// The temporary slot for a token
    private var token: Token?
    
    /// The insertion mode of the minifier
    private var mode: InsertionMode
    
    /// The level of logging
    private var level: LogLevel
    
    /// Initiates a the javascript minifier
    internal init(mode: InsertionMode = .code, log level: LogLevel = .none) {
        
        self.tokens = []
        self.mode = mode
        self.level = level
    }
    
    /// Logs the steps of the minifier depending on the log level
    private func verbose(function: String, character: Character) {
        
        switch self.level {
            
        case .debug:
            
            if character.isNewline {
                print(function, "newline")
                
            } else if character.isWhitespace {
                print(function, "whitespace")
                
            } else {
                print(function, character)
            }
            
        default:
            break
        }
    }
    
    /// Assigns a temporary token
    private func assign(token: Token) {
        
        self.verbose(function: #function, character: " ")
        
        if !(self.token?.value.isEmpty ?? true) {
            fatalError("Cannot assign the token. The previous token needs to be emitted first.")
        }
        
        self.token = token
    }
    
    /// Emits a token into the token collection
    private func emit(token: Token) {
        
        self.verbose(function: #function, character: " ")
        
        self.tokens.append(token)
    }
    
    /// Emits the temporary token into the token collection
    private func emit() {
        
        self.verbose(function: #function, character: " ")
        
        if let token = self.token {
            self.tokens.append(token)
        }
        
        self.token = nil
    }
    
    /// Consumes the content
    internal func consume(_ content: String) -> [Token] {
        
        for character in content.enumerated() {
            
            switch self.mode {
            case .beforecomment:
                self.mode = consumeBeforeComment(character.element)
                
            case .blockcomment:
                self.mode = consumeBlockComment(character.element)
                
            case .linecomment:
                self.mode = consumeLineComment(character.element)
                
            case .aftercomment:
                self.mode = consumeAfterComment(character.element)
                
            case .word:
                self.mode = consumeWord(character.element)
                
            case .string:
                self.mode = consumeStringLiteral(character.element)
                
            case .template:
                self.mode = consumeTemplateLiteral(character.element)
                
            case .numeric:
                self.mode = consumeNumericLiteral(character.element)
                
            default:
                self.mode = consumeCode(character.element)
            }
        }
        
        return self.tokens
    }
    
    /// Consumes the character
    internal func consumeCode(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isNewline {
            
            self.emit(token: WhitespaceToken(type: .return ,value: String(character)))
            
            return .code
        }
        
        if character.isWhitespace {
            
            self.emit(token: WhitespaceToken(type: .whitespace, value: String(character)))
            
            return .code
        }
        
        if character.isSemicolon || character.isColon  {
            
            self.emit(token: FormatToken(type: .terminator, value: String(character)))
            
            return .code
        }
        
        if character.isSolidus || character.isNumberSign {
            // ignore character
            return .beforecomment
        }
        
        if character.isBracket || character.isEqualSign || character.isComma || character.isPeriod {
            
            self.emit(token: FormatToken(type: .punctuator, value: String(character)))
            
            return .code
        }
        
        if character.isApostrophe  {
            
            self.assign(token: LiteralToken(type: .string, value: ""))
            
            return .string
        }
        
        if character.isBackTick {
            
            self.assign(token: LiteralToken(type: .template, value: ""))
            
            return .template
        }
        
        if character.isNumber {
            
            self.assign(token: LiteralToken(type: .numeric, value: String(character)))
            
            return .numeric
        }
        
        if character.isOperator || character.isExclamationMark || character.isPipe {
            
            self.emit(token: FormatToken(type: .operator, value: String(character)))
            
            return .code
        }
        
        if character.isLetter || character.isDollarSign || character.isUnderscore  {
            
            self.assign(token: WordToken(value: String(character)))
            
            return .word
        }
        
        return .code
    }
    
    /// Consumes the character before the comment
    internal func consumeBeforeComment(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isAsterisk  {
            
            self.assign(token: CommentToken(type: .block, value: ""))
            
            // ignore character
            return .blockcomment
        }
        
        if character.isSolidus  {
            
            self.assign(token: CommentToken(type: .line, value: ""))
            
            // ignore character
            return .linecomment
        }
        
        if character.isExclamationMark  {
            
            self.assign(token: CommentToken(type: .hashbang, value: ""))
            
            // ignore character
            return .hashbang
        }
        
        if character.isWhitespace {
            
            // Emit it as it seems to be the division operator
            self.emit(token: FormatToken(type: .operator, value: "/"))
            
            self.emit(token: WhitespaceToken(type: .whitespace, value: ""))
            
            return .code
        }
        
        // ignore character
        return .beforecomment
    }
    
    /// Consumes the character of a comment
    internal func consumeLineComment(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isNewline {
            
            self.emit()
            
            // ignore character
            return .code
        }
        
        if var token = self.token {
            token.value.append(character)
        }
        
        return .linecomment
    }
    
    /// Consumes the character of a comment
    internal func consumeBlockComment(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isAsterisk {
            
            self.emit()
            
            // ignore character
            return .aftercomment
        }
        
        if var token = self.token {
            token.value.append(character)
        }
        
        return .blockcomment
    }
    
    /// Consumes the character after a comment
    internal func consumeAfterComment(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isSolidus {
            // ignore character
            return .code
        }
        
        // ignore character
        return .aftercomment
    }
    
    internal func consumeWord(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isWhitespace {
            
            self.emit()
            
            self.emit(token: WhitespaceToken(type: .whitespace, value: ""))
            
            return .code
        }
        
        if character.isPeriod {
            
            self.emit()
            
            self.emit(token: FormatToken(type: .punctuator, value: String(character)))
            
            return .code
        }
        
        if character.isColon {
            
            self.emit()
            
            self.emit(token: FormatToken(type: .punctuator, value: String(character)))
            
            return .code
        }
        
        if character.isSemicolon {
            
            self.emit()
            
            self.emit(token: FormatToken(type: .terminator, value: String(character)))
            
            return .code
        }
        
        if character.isBracket {
            
            self.emit()
            
            self.emit(token: FormatToken(type: .punctuator, value: String(character)))
            
            return .code
        }
        
        if var token = self.token {
            token.value.append(character)
            
        } else {
            self.assign(token: WordToken(value: String(character)))
        }
        
        return .word
    }
    
    /// Consumes the character of a string literal
    internal func consumeStringLiteral(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isApostrophe {
            
            self.emit()
            
            return .code
        }
        
        if var token = self.token {
            token.value.append(character)
        }
        
        return .string
    }
    
    /// Consumes the character of a template literal
    internal func consumeTemplateLiteral(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isBackTick {
            
            self.emit()
            
            return .code
        }
        
        if var token = self.token {
            token.value.append(character)
        }
        
        return .template
    }
    
    /// Consumes the character of a numeric literal
    internal func consumeNumericLiteral(_ character: Character) -> InsertionMode {
        
        self.verbose(function: #function, character: character)
        
        if character.isSemicolon {
            
            self.emit()
            
            self.emit(token: FormatToken(type: .terminator, value: String(character)))
            
            return .code
        }
        
        if character.isBracket {
            
            self.emit()
            
            self.emit(token: FormatToken(type: .punctuator, value: String(character)))
            
            return .code
        }
        
        if character.isWhitespace {
            
            self.emit()
            
            self.emit(token: WhitespaceToken(type: .whitespace, value: ""))
            
            return .code
        }
        
        if var token = self.token {
            token.value.append(character)
        }
        
        return .numeric
    }
}

extension Javascript {
    
    internal class WhitespaceToken: Token {
        
        /// A enumeration of the variations of comment tokens
        internal enum TokenType {
            
            /// Indicates a single line comment
            case whitespace
            
            /// Indicates a multiline comment
            case `return`
        }
        
        /// The type of the token
        internal var type: TokenType
        
        /// The value of the token
        internal var value: String
        
        /// Initiates a comment token
        internal init(type: TokenType, value: String) {
            
            self.type = type
            self.value = value
        }
        
        internal func present() -> String {
            
            switch type {
            case .return:
                return "\r\n"
                
            case .whitespace:
                return " "
            }
        }
    }
    
    /// A type that represents a javascript comment
    internal class CommentToken: Token {
        
        /// A enumeration of the variations of comment tokens
        internal enum TokenType {
            
            /// Indicates a single line comment
            case line
            
            /// Indicates a multiline comment
            case block
            
            /// Indicates a hashbang comment
            case hashbang
        }
        
        /// The type of the token
        internal var type: TokenType
        
        /// The value of the token
        internal var value: String
        
        /// Initiates a comment token
        internal init(type: TokenType, value: String) {
            
            self.type = type
            self.value = value
        }
        
        /// Minifies a comment token
        internal func present() -> String {
            
            switch type {
            case .line:
                return "//\(value)"
                
            case .block:
                return "/*\(value)*/"
                
            case .hashbang:
                return "#!\(value)"
            }
        }
    }
    
    /// A type that represents a javascript literal
    internal class LiteralToken: Token {
        
        /// A enumeration of the variations of literal tokens
        internal enum TokenType {
            
            /// Indiciates a boolean literal
            case boolean
            
            /// Indiciates a string literal
            case string
            
            /// Indiciates a template literal
            case template
            
            /// Indiciates a numeric literal
            case numeric
            
            /// Indiciates a null value
            case null
            
            /// Indiciates regular expression
            case regularexpression
        }
        
        /// The type of the token
        internal var type: TokenType
        
        /// The value of the token
        internal var value: String
        
        /// Initiates a literal token
        internal init(type: TokenType, value: String) {
            
            self.type = type
            self.value = value
        }
        
        /// Minifies a literal token
        internal func present() -> String {
            
            switch type {
            case .string:
                return "'\(value)'"
                
            case .template:
                return "`\(value)`"
                
            default:
                return value
            }
        }
    }
    
    /// A type that represents a format control token
    internal class FormatToken: Token {
        
        /// A enumeration of the variation of format tokens
        internal enum TokenType {
            
            /// Indicates a punctiation
            case punctuator
            
            /// Indicates a line terminator character
            case terminator
            
            /// Indicates a line operator character
            case `operator`
        }
        
        /// The type of the token
        internal var type: TokenType
        
        /// The value of the token
        internal var value: String
        
        /// Initiates a format token
        internal init(type: TokenType, value: String) {
            
            self.type = type
            self.value = value
        }
        
        /// Minifies a format token
        internal func present() -> String {
            return value
        }
    }
    
    /// A type that represents a word token
    internal class WordToken: Token {
        
        /// A enumeration of the variations of word tokens
        internal enum TokenType {
            
            /// Indicates a reserved word
            case keyword
            
            /// Indicates a identifier
            case identifier
        }
        
        /// The type of the token
        internal var type: TokenType {
            
            if !keywords.contains(value) {
                return .identifier
            }
            
            return .keyword
        }
        
        /// The value of the token
        internal var value: String
        
        /// Initiates a word token
        internal init(value: String) {
            
            self.value = value
        }
        
        /// Minifies a word token
        internal func present() -> String {
            return value
        }
        
        /// A set of keywords
        private var keywords: Set<String> {
            return [
                "await",
                "break",
                "case",
                "catch",
                "class",
                "const",
                "continue",
                "debugger",
                "default",
                "delete",
                "do",
                "else",
                "enum",
                "export",
                "extends",
                "false",
                "finally",
                "for",
                "function",
                "if",
                "implements",
                "import",
                "in",
                "instanceof",
                "interface",
                "let",
                "new",
                "null",
                "package",
                "private",
                "protected",
                "public",
                "return",
                "super",
                "switch",
                "static",
                "this",
                "throw",
                "try",
                "true",
                "typeof",
                "var",
                "void",
                "while",
                "with",
                "yield",
                "of"
            ]
        }
    }
}

*/
