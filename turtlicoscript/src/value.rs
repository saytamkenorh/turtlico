extern crate proc_macro;

use std::{collections::HashMap, fmt::Display, any::Any, rc::Weak};

use crate::{error::RuntimeError, ast::{Expression, Spanned}};

pub type NativeFuncReturn = Result<Value, RuntimeError>;
pub type FuncThisObject = Option<Weak<std::cell::RefCell<ValueObject>>>;
pub type NativeFuncArgs = Vec<Value>;
pub type NativeFuncCtxArg = Box<dyn LibraryContext>;
pub type ValueObject = HashMap<HashableValue, Value>;

#[derive(Clone)]
pub struct NativeFunc {
    pub this: FuncThisObject,
    pub library: String,
    pub func: fn(&mut NativeFuncCtxArg, FuncThisObject, NativeFuncArgs) -> NativeFuncReturn
}

#[derive(Clone)]
pub struct TSFunc {
    pub body: Spanned<Expression>,
    pub args: Vec<String>
}

#[derive(Clone)]
pub enum Callable {
    Function(Box<TSFunc>),
    NativeFunc(NativeFunc)
}

#[derive(Hash, Eq, PartialEq, Debug, Clone)]
pub enum HashableValue {
    String(String),
    Int(i32),
}

#[derive(Debug, Clone)]
pub enum Value {
    Int(i32),
    Float(f64),
    String(String),
    Image(String),
    Bool(bool),
    Callable(Callable),
    Object(std::rc::Rc<std::cell::RefCell<ValueObject>>),
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
                    $crate::value::NativeFunc{this: None, func: $x, library: $name.to_owned()})));
            )*
            map
        }
    };
}

#[macro_export]
macro_rules! funcmap_obj {
    ( $name:expr, $obj:expr, $( $x:expr ),* ) => {
        {
            let mut map = std::collections::HashMap::new();
            $(
                map.insert(
                    $crate::value::HashableValue::String(stringify!($x).replace("::", ".").to_owned()),
                    $crate::value::Value::Callable($crate::value::Callable::NativeFunc(
                        $crate::value::NativeFunc{this: $obj, func: $x, library: $name.to_owned()})
                    )
                );
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

pub fn unwrap_context<T: 'static>(ctx: &mut NativeFuncCtxArg) -> &mut T {
    (&mut *ctx).as_any_mut().downcast_mut::<T>().expect("Invalid context type")
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

impl TryFrom<Value> for HashableValue {
    type Error = crate::error::RuntimeError;
    fn try_from(val: Value) -> Result<Self, Self::Error> {
        match val {
            Value::String(str) => {
                Ok(Self::String(str))
            },
            Value::Int(int) => {
                Ok(Self::Int(int))
            },
            _ => {
                Err(RuntimeError::TypeHashUnsupported)
            }
        }
    }
}
impl From<&str> for HashableValue {
    fn from(value: &str) -> Self {
        Self::String(value.to_owned())
    }
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

impl From<HashMap<HashableValue, Value>> for Value {
    fn from(value: HashMap<HashableValue, Value>) -> Self {
        Value::Object(std::rc::Rc::new(std::cell::RefCell::new(value)))
    }
}

impl TryInto<f64> for Value {
    fn try_into(self) -> Result<f64, crate::error::RuntimeError> {
        match self {
            Value::Float(val) => {
                Ok(val)
            },
            _ => {
                Err(RuntimeError::TypeError)
            }
        }
    }

    type Error = crate::error::RuntimeError;
}

impl TryInto<i32> for Value {
    fn try_into(self) -> Result<i32, crate::error::RuntimeError> {
        match self {
            Value::Int(val) => {
                Ok(val)
            },
            _ => {
                Err(RuntimeError::TypeError)
            }
        }
    }

    type Error = crate::error::RuntimeError;
}

impl Display for Value {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Value::Int(val) => write!(f, "{}", val),
            Value::Float(val) => write!(f, "{}", val),
            Value::String(val) => write!(f, "{}", val),
            Value::Image(val) => write!(f, "Image: {}", val),
            Value::Bool(val) => write!(f, "{}", val),
            Value::Callable(val) => write!(f, "{}", val),
            Value::Object(val) => write!(f, "{:?}", val),
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
            Value::Image(_) => "image",
            Value::Bool(_) => "bool",
            Value::Callable(_) => "callable",
            Value::Object(_) => "object",
            Value::EvaluatedReturn(_) => "return",
            Value::Break => "break",
            Value::None => "none"
        }
    }
}