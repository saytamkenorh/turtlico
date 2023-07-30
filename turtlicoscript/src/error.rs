use std::fmt::Display;

use chumsky::prelude::Simple;

use crate::{tokens::Token, ast::Spanned};

#[derive(Debug, Clone)]
pub enum Error {
    InvalidToken,
    UnexpectedToken(Token),
    SyntaxError(Simple<Token>),
    ThisCannotBeCalled(String),
    ThisIsNotAssignable,
    InvalidIterationCount,
    InvalidForStart,
    InvalidForEnd,
    InvalidForStep,
    RuntimeError(RuntimeError),
    TypeError(String),
    Interrupted,
}

impl Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

impl Spanned<Error> {
    pub fn build_message(&self, source: &str) -> String {
        let error_start = source[..self.span.start].rfind('\n').unwrap_or(0);
        let error_end = source[self.span.end..].find('\n').map_or(source.len(), |i| self.span.end + i);

        let mut i = 0;
        let mut i_line = 0;
        let error_line = loop {
            if let Some(char) = source.chars().nth(i) {
                if char == '\n' {
                    i_line += 1;
                }
                if i >= self.span.start {
                    break Some(i_line)
                }
            } else {
                break None
            }
            i += 1;
        }.unwrap_or(0);

        // https://chrisyeh96.github.io/2020/03/28/terminal-colors.html
        let mut bad_code = source[error_start..error_end].trim_matches('\n').to_owned();
        println!("{}:{} {}:{}", error_start, error_end, self.span.start, self.span.end);

        let line_error_start = isize::max(self.span.start as isize - error_start as isize - 1, 0) as usize;
        let line_error_end = usize::min(self.span.end - error_start - 1, bad_code.len());

        bad_code.insert_str(line_error_end, "\x1b[0m");
        bad_code.insert_str(line_error_start, "\x1b[41m");
        format!("An \x1b[31merror\x1b[0m occurred on line {}:\n{}\n\x1b[33m{}\x1b[0m", error_line + 1, bad_code, self.item)
    }
}

#[derive(Debug, Hash, Clone)]
pub enum RuntimeError {
    /// Invalid argument count (found, expected)
    InvalidArgCount(usize, usize),
    /// Invalid argument type (position)
    InvalidArgType(usize),
    InvalidIdentifier(String),
    /// Value cannot be parsed to target type due to an error (invalid format etc)
    TypeParseError(String),
    /// Value cannot be parsed to target type (value type, target)
    TypeParseUnsupported(String, String),
    TypeHashUnsupported,
    TypeError,
    InvalidBlock(String),
    NativeLibraryError(String),
    MethodCalledAsFunction,
}

impl Display for RuntimeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}