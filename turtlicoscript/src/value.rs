extern crate proc_macro;

use std::{collections::HashMap, fmt::Display, any::Any};

use crate::{error::RuntimeError, ast::Expression};

pub type NativeFuncReturn = Result<Value, RuntimeError>;
pub type NativeFuncArgs = Vec<Value>;
pub type NativeFuncCtxArg = Box<dyn LibraryContext>;

#[derive(Clone)]
pub struct NativeFunc {
    pub library: String,
    pub func: fn(&mut NativeFuncCtxArg, NativeFuncArgs) -> NativeFuncReturn
}

#[derive(Clone)]
pub enum Callable {
    Function(Box<Expression>),
    NativeFunc(NativeFunc)
}

#[derive(Debug, Clone)]
pub enum Value {
    Int(i32),
    Float(f64),
    String(String),
    Bool(bool),
    Callable(Callable),
    EvaluatedReturn(Box<Value>),
    Break,
    None,
}

pub struct Library {
    pub name: String,
    pub vars: HashMap<String, Value>,
    pub context: Box<dyn LibraryContext>
}

pub trait LibraryContext {
    fn as_any_mut(&mut self) -> &mut dyn Any;
}

#[macro_export]
macro_rules! funcmap {
    ( $name:expr, $( $x:expr ),* ) => {
        {
            let mut map = std::collections::HashMap::new();
            $(
                map.insert(stringify!($x).replace("::", ".").to_owned(), $crate::value::Value::Callable($crate::value::Callable::NativeFunc(
                    $crate::value::NativeFunc{func: $x, library: $name.to_owned()})));
            )*
            map
        }
    };
}

#[macro_export]
macro_rules! check_argc {
    ( $args:expr, $count:expr ) => {
        {
            if ($args.len()!= $count) {
                return Err($crate::error::RuntimeError::InvalidArgCount($args.len(), $count))
            }
        }
    };
}

impl From<i32> for Value {
    fn from(val: i32) -> Self {
        Value::Int(val)
    }
}

impl From<&str> for Value {
    fn from(val: &str) -> Self {
        Value::String(val.to_owned())
    }
}

impl From<f64> for Value {
    fn from(val: f64) -> Self {
        Value::Float(val)
    }
}

impl Display for Callable {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Callable::Function(_) => write!(f, "<Function>"),
            Callable::NativeFunc(_) => write!(f, "<Native function>")
        }
    }
}

impl std::fmt::Debug for Callable {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        Display::fmt(&self, f)
    }
}

impl Display for Value {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Value::Int(val) => write!(f, "{}", val),
            Value::Float(val) => write!(f, "{}", val),
            Value::String(val) => write!(f, "{}", val),
            Value::Bool(val) => write!(f, "{}", val),
            Value::Callable(val) => write!(f, "{}", val),
            Value::EvaluatedReturn(val) => write!(f, "<Return value: {}>", *val),
            Value::Break => write!(f, "<Break>"),
            Value::None => write!(f, "None")
        }
    }
}

impl Value {
    pub fn type_to_string(&self) -> &str {
        match self {
            Value::Int(_) => "int",
            Value::Float(_) => "float",
            Value::String(_) => "string",
            Value::Bool(_) => "bool",
            Value::Callable(_) => "callable",
            Value::EvaluatedReturn(_) => "return",
            Value::Break => "break",
            Value::None => "none"
        }
    }
}