use std::{fmt::Debug, ops::Range};

#[derive(Clone)]
pub struct Spanned<T> {
    pub item: T,
    pub span: Range<usize>,
}
impl<T> Spanned<T> {
    pub fn new(item: T, span: Range<usize>) -> Self {
        Self { item, span }
    }
}
impl<T: Debug> Debug for Spanned<T> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        if f.alternate() {
            write!(f, "{:#?} @ {:?}", self.item, self.span)
        } else {
            write!(f, "{:?} @ {:?}", self.item, self.span)
        }
    }
}
impl<T: PartialEq> PartialEq for Spanned<T> {
    fn eq(&self, other: &Self) -> bool {
        self.item == other.item
    }
}

// In TurlicoScript everything is an expression.
// Some expressions can be used as statements
// This means that their value does not have to be used
#[derive(Debug, Clone)]
pub enum Expression {
    Call {
        expr: Box<Spanned<Expression>>,
        args: Vec<Spanned<Expression>>,
    },
    Assignment {
        expr: Box<Spanned<Expression>>,
        value: Box<Spanned<Expression>>,
    },
    ObjDef {
        object: Vec<(Spanned<Expression>, Spanned<Expression>)>
    },
    Return {
        value: Box<Spanned<Expression>>,
    },
    Break,

    // Loops
    If {
        cond: Box<Spanned<Expression>>,
        body: Box<Spanned<Expression>>,
    },
    LoopFinite {
        iters: Box<Spanned<Expression>>,
        body: Box<Spanned<Expression>>,
    },
    LoopInfinite {
        body: Box<Spanned<Expression>>,
    },
    For {
        var: String,
        start: Box<Spanned<Expression>>,
        end: Box<Spanned<Expression>>,
        step: Option<Box<Spanned<Expression>>>,
        body: Box<Spanned<Expression>>,
    },
    While {
        cond: Box<Spanned<Expression>>,
        body: Box<Spanned<Expression>>,
    },

    // Structure
    FnDef {
        name: String,
        args: Vec<String>,
        body: Box<Spanned<Expression>>,
    },

    // Operators
    Negation(Box<Spanned<Expression>>),
    Multiply(Box<Spanned<Expression>>, Box<Spanned<Expression>>),
    Division(Box<Spanned<Expression>>, Box<Spanned<Expression>>),
    Addition(Box<Spanned<Expression>>, Box<Spanned<Expression>>),
    Subtraction(Box<Spanned<Expression>>, Box<Spanned<Expression>>),
    Eq(Box<Spanned<Expression>>, Box<Spanned<Expression>>),
    Neq(Box<Spanned<Expression>>, Box<Spanned<Expression>>),
    Lt(Box<Spanned<Expression>>, Box<Spanned<Expression>>),
    Gt(Box<Spanned<Expression>>, Box<Spanned<Expression>>),
    Lte(Box<Spanned<Expression>>, Box<Spanned<Expression>>),
    Gte(Box<Spanned<Expression>>, Box<Spanned<Expression>>),

    // Literals
    Int(i32),
    Float(f64),
    String(String),
    Image(String),
    Key(String),
    Variable {
        parent: Option<Box<Spanned<Expression>>>,
        name: String
    },
    None,

    Block(Vec<Spanned<Expression>>),
}