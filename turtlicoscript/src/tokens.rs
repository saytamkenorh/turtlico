use logos::{Lexer, Logos, Source};

#[derive(Logos, Debug, PartialEq, Clone, Hash, Eq)]
pub enum Token {
    #[regex(r"#.*")]
    Comment,

    // Keywords
    #[token("if")]
    If,
    #[token("return")]
    Return,
    #[token("break")]
    Break,
    #[token("loop")]
    Loop,
    #[token("for")]
    For,
    #[token("while")]
    While,
    #[token("fn")]
    Fn,

    #[regex(r"\$[\p{XID_Continue}]+", get_indentifier_var)]
    Variable(String),
    #[regex(r"\p{XID_Start}[\p{XID_Continue}]+", get_indentifier)]
    Function(String),
    // Literals
    /// String
    #[regex(r#""([^"\\]|\\t|\\u|\\n|\\")*""#, get_string)]
    String(String),
    /// Numbers
    #[regex(r"[0-9]+", get_value, priority=4)]
    Integer(i32),
    #[regex(r"[0-9]+\.?[0-9]+|inf", get_value, priority=3)]
    Float(String),

    // Symbols
    #[token("(")]
    LeftParent,
    #[token(")")]
    RightParent,
    #[token("{")]
    LeftCurly,
    #[token("}")]
    RightCurly,
    #[token(",")]
    Comma,
    #[token("==")]
    Comparison,
    #[token("=")]
    Assignment,

    // Ops
    #[token("+")]
    Plus,
    #[token("-")]
    Minus,
    #[token("*")]
    Star,
    #[token("/")]
    Slash,

    #[regex(r"[ \t\n\f]+", logos::skip)]

    #[error]
    Error,
}

fn get_indentifier(lexer: &mut Lexer<Token>) -> String {
    lexer.slice().to_owned()
}

fn get_indentifier_var(lexer: &mut Lexer<Token>) -> String {
    lexer.slice().trim_start_matches('$').to_owned()
}


fn get_value<T: std::str::FromStr>(lexer: &mut Lexer<Token>) -> Option<T> {
    lexer.slice().parse().ok()
}

fn get_string(lexer: &mut Lexer<Token>) -> Option<String> {
    let slice = lexer.slice();
    slice.slice(1..slice.len() - 1).unwrap().parse().ok()
}