use std::{collections::{HashMap, HashSet}, sync::{Arc, atomic::AtomicBool}, ops::Range};

use chumsky::prelude::Simple;

use crate::{ast::{Expression, Spanned}, error::{Error, RuntimeError}, value::{Value, Library, Callable, LibraryContext, TSFunc, TSObject}, stdlib};

pub type CancellationToken = Arc<AtomicBool>;

enum MathOperator {
    Addition,
    Subtraction,
    Multiply,
    Division,
    Eq,
    Neq,
    Lt,
    Gt,
    Lte,
    Gte
}

pub struct Context {
    pub stack: Vec<Scope>,
    libctx: HashMap<String, Box<dyn LibraryContext>>,
    pub cancellable: Option<CancellationToken>,
}

pub struct Scope {
    pub vars: HashMap<String, Value>,
    pub vars_props: HashSet<String>
}

impl Scope {
    pub fn new() -> Self {
        Self { vars: HashMap::new(), vars_props: HashSet::new() }
    }
}

impl Context {
    pub fn new_parent(cancellable: Option<CancellationToken>) -> Self {
        let mut this = Self {
            stack: vec![Scope::new()],
            libctx: HashMap::new(),
            cancellable: cancellable,
        };
        this.import_library(stdlib::init_library(), false);
        this
    }

    #[inline(always)]
    fn get_scope(&mut self) -> &mut Scope {
        return self.stack.last_mut().unwrap();
    }

    pub fn eval_root(&mut self, expression: &Spanned<Expression>) -> Result<Value, Spanned<Error>> {
        match self.eval(expression)  {
            Ok(Value::EvaluatedReturn(value)) => Ok(*value),
            other => other
        }
    }

    fn eval(&mut self, expression: &Spanned<Expression>) -> Result<Value, Spanned<Error>> {
        if let Some(cancellable) = &self.cancellable {
            if cancellable.load(std::sync::atomic::Ordering::Relaxed) {
                return Err(Spanned::new(Error::Interrupted, expression.span.to_owned()));
            }
        }
        match &expression.item {
            Expression::Block(block) => {
                let mut last_result = Value::None;
                for expr in block {
                    match self.eval(&expr)?{
                        Value::EvaluatedReturn(value) => {
                            return Ok(Value::EvaluatedReturn(value));
                        },
                        Value::Break => {
                            return Ok(Value::Break)
                        },
                        value => {
                            last_result = value;
                        }
                    }

                }
                Ok(last_result)
            }
            Expression::Call { expr, args } => {
                match self.eval(&expr)? {
                    Value::Callable(callable) => {
                        self.call_callable(&callable, expression.span.to_owned(), args)
                    }
                    value => {
                        Err(Spanned::new(Error::ThisCannotBeCalled(value.to_string()), expression.span.to_owned()))
                    }
                }

            },
            // Control flow
            Expression::If {cond, body} => {
                let cond_res = self.eval(&cond)?;
                if matches!(cond_res, Value::Bool(true)) {
                    self.eval(&body)
                } else {
                    Ok(Value::None)
                }
            }
            // Loops
            Expression::LoopInfinite { body } => {
                loop {
                    match self.eval(&body)? {
                        Value::Break => {
                            break Ok(Value::None);
                        }
                        _ => {}
                    }
                }
            },
            Expression::LoopFinite { iters, body } => {
                match self.eval(&iters)? {
                    Value::Int(n) => {
                        for _ in 0..n {
                            match self.eval(&body)? {
                                Value::Break => {
                                    break;
                                }
                                _ => {}
                            }
                        }
                        Ok(Value::None)
                    },
                    _ => {
                        Err(Spanned::new(Error::InvalidIterationCount, iters.span.to_owned()))
                    }
                }
            },
            Expression::For { var, start, end, step, body } => {
                let vstart = self.eval(&start)?;
                let vend = self.eval(&end)?;
                let vstep = step.as_ref().map(|v| self.eval(&v)).unwrap_or(Ok(Value::Int(1)))?;
                match vstart {
                    Value::Int(start) => {
                        match vend {
                            Value::Int(end) => {
                                match vstep {
                                    Value::Int(step) => {
                                        let mut i = start;
                                        while i < end {
                                            self.get_scope().vars.insert(var.to_owned(), Value::Int(i));
                                            match self.eval(&body)? {
                                                Value::Break => {
                                                    break;
                                                }
                                                _ => {}
                                            }
                                            i += step;
                                        }
                                        Ok(Value::None)
                                    },
                                    _ => {
                                        let span = &step.as_ref().unwrap().span;
                                        Err(Spanned::new(Error::InvalidForStep, span.to_owned()))
                                    }
                                }
                            },
                            _ => {
                                Err(Spanned::new(Error::InvalidForEnd, end.span.to_owned()))
                            }
                        }
                    },
                    _ => {
                        Err(Spanned::new(Error::InvalidForStart, start.span.to_owned()))
                    }
                }
            },
            Expression::While { cond, body } => {
                loop {
                    let cond = self.eval(&cond)?;
                    if !matches!(cond, Value::Bool(true)) {
                        break;
                    }
                    match self.eval(&body)? {
                        Value::Break => {
                            break;
                        }
                        _ => {}
                    }
                }
                Ok(Value::None)
            },
            // Structure
            Expression::FnDef { name, args, body } => {
                let func = TSFunc {
                    body: (**body).clone(),
                    args: args.to_owned()
                };
                self.get_scope().vars.insert(name.to_owned(), Value::Callable(Callable::Function(Box::new(func))));
                Ok(Value::None)
            }

            // Keywords
            Expression::Assignment { expr, value } => {
                match &expr.item {
                    Expression::Variable{parent, name} => {
                        let value = self.eval(&value)?;
                        match parent {
                            Some(parent) => {
                                let parent = self.eval(parent)?;
                                match parent {
                                    Value::Object(object) => {
                                        let mut hashmap = (*object).borrow_mut();
                                        let oldval = hashmap.fields.insert(
                                            crate::value::HashableValue::String(name.to_owned()), value);
                                        Ok(oldval.unwrap_or(Value::None))
                                    },
                                    _ => {
                                        Err(Spanned::new(Error::TypeError("This is not an object".to_owned()), expr.span.to_owned()))
                                    }
                                }
                            },
                            None => {
                                let oldval = self.get_scope().vars.insert(name.to_owned(), value);
                                Ok(oldval.unwrap_or(Value::None))
                            }
                        }
                    },
                    _ => {
                        Err(Spanned::new(Error::ThisIsNotAssignable, expr.span.to_owned()))
                    }
                }
            },
            Expression::Return { value } => {
                self.eval(&value).map(|val| Value::EvaluatedReturn(Box::new(val)))
            },
            Expression::Break => {
                Ok(Value::Break)
            },
            // Operators
            Expression::Negation(a) => {
                match &self.eval(&a)? {
                    Value::Int(num) => { Ok(Value::Int(-num)) },
                    Value::Float(num) => { Ok(Value::Float(-num)) },
                    val => Err(Spanned::new(Error::TypeError(
                        format!("Incompatible type ({}) for this operator", val.type_to_string()).to_owned()), expression.span.to_owned()))
                }
            },
            Expression::Addition(a, b) => {
                self.math_operator(a, b, MathOperator::Addition)
            },
            Expression::Subtraction(a, b) => {
                self.math_operator(a, b, MathOperator::Subtraction)
            },
            Expression::Multiply(a, b) => {
                self.math_operator(a, b, MathOperator::Multiply)
            },
            Expression::Division(a, b) => {
                self.math_operator(a, b, MathOperator::Division)
            },
            Expression::Eq(a, b) => {
                self.math_operator(a, b, MathOperator::Eq)
            },
            Expression::Neq(a, b) => {
                self.math_operator(a, b, MathOperator::Neq)
            },
            Expression::Lt(a, b) => {
                self.math_operator(a, b, MathOperator::Lt)
            },
            Expression::Gt(a, b) => {
                self.math_operator(a, b, MathOperator::Gt)
            },
            Expression::Lte(a, b) => {
                self.math_operator(a, b, MathOperator::Lte)
            },
            Expression::Gte(a, b) => {
                self.math_operator(a, b, MathOperator::Gte)
            },
            // Literals
            Expression::Int(val) => Ok(Value::Int(*val)),
            Expression::Float(val) => Ok(Value::Float(*val)),
            Expression::String(val) => Ok(Value::String(val.to_owned())),
            Expression::Image(val) => Ok(Value::Image(val.to_owned())),
            Expression::Key(val) => Ok(Value::Key(val.to_owned())),
            Expression::Variable {parent, name} => {
                match parent {
                    Some(parent) => {
                        let object = self.eval(parent)?;
                        Ok(self.get_var(&name, Some(object)).map_err(|err: Error| Spanned::new(err, expression.span.to_owned()))?)

                    },
                    None => {
                        Ok(self.get_var(&name, None).map_err(|err: Error| Spanned::new(err, expression.span.to_owned()))?)
                    }
                }
            },
            Expression::ObjDef {object} => {
                let mut fields = HashMap::new();
                for item in object {
                    fields.insert(self.eval(&item.0)?.try_into().map_err(|err: RuntimeError| {
                        Spanned { item: Error::RuntimeError(err), span: item.0.span.clone() }
                    })?, self.eval(&item.1)?);
                }
                Ok(Value::Object(std::rc::Rc::new(
                    std::cell::RefCell::new(TSObject { fields: fields, fields_props: HashSet::new() })
                )))
            },
            _ => {
                Err(Spanned::new(Error::SyntaxError(
                    Simple::custom(expression.span.clone(),
                    format!("Interpreter error: unexpected expression {:?}", expression.item))
                ), expression.span.to_owned()))
            }
        }
    }

    fn get_var(&mut self, name: &str, parent_obj: Option<Value>) -> Result<Value, Error> {
        match parent_obj {
            Some (parent_obj) => {
                match parent_obj {
                    Value::Object(object) => {
                        let object = object.borrow();
                        let field_name = &crate::value::HashableValue::String(name.to_owned());
                        match object.fields.get(field_name) {
                            Some (value) => {
                                if object.fields_props.contains(field_name) {
                                    match value {
                                        Value::Callable(callable) => {
                                            self.call_callable(callable, Range { start: 0, end: 0 }, &vec![]).map_err(|err| err.item)
                                        },
                                        _ => {
                                            Err(Error::TypeError("Property field is not a callable".to_owned()))
                                        }
                                    }
                                } else {
                                    Ok(value.clone())
                                }
                            },
                            None => Err(Error::RuntimeError(RuntimeError::InvalidIdentifier(name.to_owned())))
                        }
                    },
                    _ => {
                        Err(Error::TypeError("This is not an object".to_owned()))
                    }
                }
            },
            None => {
                for scope in self.stack.iter_mut().rev() {
                    if let Some(value) = scope.vars.get(name) {
                        return if scope.vars_props.contains(name) {
                            match value.clone() {
                                Value::Callable(callable) => {
                                    self.call_callable(&callable, Range { start: 0, end: 0 }, &vec![]).map_err(|err| err.item)
                                },
                                _ => {
                                    Err(Error::TypeError("Property field is not a callable".to_owned()))
                                }
                            }
                        } else {
                            Ok(value.clone())
                        };
                    }
                }
                return Err(Error::RuntimeError(RuntimeError::InvalidIdentifier(name.to_owned())));
            }
        }
    }

    fn call_callable(&mut self, callable: &Callable, span: Range<usize>, args: &Vec<Spanned<Expression>>) -> Result<Value, Spanned<Error>> {
        match callable {
            Callable::NativeFunc(func) => {
                //let func = self.get_var(&name)?;
                let mut func_args = vec![];
                for arg in args {
                    func_args.push(self.eval(&arg)?);
                }
                let ctx = self.libctx.get_mut(&func.library).unwrap();
                let result = (func.func)(ctx, func.this.clone(), func_args).map_err(
                    |err| Spanned::new(Error::RuntimeError(err), span));
                match result {
                    Ok(Value::EvaluatedReturn(value)) => {
                        return Ok(*value);
                    },
                    other_result => other_result
                }
            },
            Callable::Function(func) => {
                let mut args_evaluated: Vec<(String, Value)> = vec![];
                if func.args.len() != args.len() {
                    return Err(
                            Spanned::new(
                                Error::RuntimeError(RuntimeError::InvalidArgCount(args.len(), func.args.len())), span)
                        );
                }
                for (argi, argname) in func.args.iter().enumerate() {
                    args_evaluated.push((argname.to_owned(), self.eval(&args[argi])?));
                }
                let mut subst = Scope::new();
                subst.vars.extend(args_evaluated);
                self.stack.push(subst);
                let result = match self.eval(&func.body)? {
                    Value::EvaluatedReturn(val) => {
                        Ok(*val)
                    },
                    other => Ok(other)
                };
                self.stack.pop();
                result
            }
        }
    }

    pub fn import_library(&mut self, lib: Library, prefix_name: bool) {
        let libname = lib.name;
        self.stack[0].vars.extend(lib.scope.vars.into_iter().map(|(key, value)| {
            (if prefix_name {libname.to_owned() + "." + &key} else {key}, value)
        }));
        self.stack[0].vars_props.extend(lib.scope.vars_props.into_iter().map(|prop| {
            if prefix_name {libname.to_owned() + "." + &prop} else {prop}
        }));
        self.libctx.insert(libname, lib.context);
    }

    fn math_operator(&mut self, expr_a: &Box<Spanned<Expression>>, expr_b: &Box<Spanned<Expression>>, op: MathOperator) -> Result<Value, Spanned<Error>> {
        let span_a = expr_a.span.clone();
        let span_b = expr_b.span.clone();
        let a = &self.eval(&expr_a)?;
        let b = &self.eval(&expr_b)?;
        match a {
            Value::Int(val_a) => {
                match b {
                    Value::Int(val_b) => {
                        match op {
                            MathOperator::Addition => Ok(Value::Int(val_a + val_b)),
                            MathOperator::Subtraction => Ok(Value::Int(val_a - val_b)),
                            MathOperator::Multiply => Ok(Value::Int(val_a * val_b)),
                            MathOperator::Division => Ok(Value::Int(val_a / val_b)),
                            MathOperator::Eq => Ok(Value::Bool(val_a == val_b)),
                            MathOperator::Neq => Ok(Value::Bool(val_a != val_b)),
                            MathOperator::Lt => Ok(Value::Bool(val_a < val_b)),
                            MathOperator::Gt => Ok(Value::Bool(val_a > val_b)),
                            MathOperator::Lte => Ok(Value::Bool(val_a <= val_b)),
                            MathOperator::Gte => Ok(Value::Bool(val_a >= val_b)),
                        }
                    },
                    Value::Float(val_b) => {
                        match op {
                            MathOperator::Addition => Ok(Value::Float(f64::from(*val_a) + val_b)),
                            MathOperator::Subtraction => Ok(Value::Float(f64::from(*val_a) - val_b)),
                            MathOperator::Multiply => Ok(Value::Float(f64::from(*val_a) * val_b)),
                            MathOperator::Division => Ok(Value::Float(f64::from(*val_a) / val_b)),
                            MathOperator::Eq => Ok(Value::Bool(f64::from(*val_a) == *val_b)),
                            MathOperator::Neq => Ok(Value::Bool(f64::from(*val_a) != *val_b)),
                            MathOperator::Lt => Ok(Value::Bool(f64::from(*val_a) < *val_b)),
                            MathOperator::Gt => Ok(Value::Bool(f64::from(*val_a) > *val_b)),
                            MathOperator::Lte => Ok(Value::Bool(f64::from(*val_a) <= *val_b)),
                            MathOperator::Gte => Ok(Value::Bool(f64::from(*val_a) >= *val_b)),
                        }
                    },
                    _ => Err(Spanned::new(Error::TypeError(
                        format!("Incompatible types ({} and {}) for this operator", a.type_to_string(), b.type_to_string()).to_owned()),
                        span_b))
                }
            },
            Value::Float(val_a) => {
                match b {
                    Value::Float(val_b) => {
                        match op {
                            MathOperator::Addition => Ok(Value::Float(val_a + val_b)),
                            MathOperator::Subtraction => Ok(Value::Float(val_a - val_b)),
                            MathOperator::Multiply => Ok(Value::Float(val_a * val_b)),
                            MathOperator::Division => Ok(Value::Float(val_a / val_b)),
                            MathOperator::Eq => Ok(Value::Bool(val_a == val_b)),
                            MathOperator::Neq => Ok(Value::Bool(val_a != val_b)),
                            MathOperator::Lt => Ok(Value::Bool(val_a < val_b)),
                            MathOperator::Gt => Ok(Value::Bool(val_a > val_b)),
                            MathOperator::Lte => Ok(Value::Bool(val_a <= val_b)),
                            MathOperator::Gte => Ok(Value::Bool(val_a >= val_b)),
                        }
                    },
                    Value::Int(val_b) => {
                        match op {
                            MathOperator::Addition => Ok(Value::Float(val_a + f64::from(*val_b))),
                            MathOperator::Subtraction => Ok(Value::Float(val_a - f64::from(*val_b))),
                            MathOperator::Multiply => Ok(Value::Float(val_a * f64::from(*val_b))),
                            MathOperator::Division => Ok(Value::Float(val_a / f64::from(*val_b))),
                            MathOperator::Eq => Ok(Value::Bool(*val_a == f64::from(*val_b))),
                            MathOperator::Neq => Ok(Value::Bool(*val_a != f64::from(*val_b))),
                            MathOperator::Lt => Ok(Value::Bool(*val_a < f64::from(*val_b))),
                            MathOperator::Gt => Ok(Value::Bool(*val_a > f64::from(*val_b))),
                            MathOperator::Lte => Ok(Value::Bool(*val_a <= f64::from(*val_b))),
                            MathOperator::Gte => Ok(Value::Bool(*val_a >= f64::from(*val_b))),
                        }
                    },
                    _ => Err(Spanned::new(Error::TypeError(
                        format!("Incompatible types ({} and {}) for this operator", a.type_to_string(), b.type_to_string()).to_owned()),
                        span_b))
                }
            },
            Value::String(val_a) => {
                match b {
                    Value::String(val_b) => {
                        match op {
                            MathOperator::Addition => Ok(Value::String(val_a.to_owned() + val_b)),
                            MathOperator::Eq => Ok(Value::Bool(val_a == val_b)),
                            MathOperator::Neq => Ok(Value::Bool(val_a != val_b)),
                            _ => Err(Spanned::new(Error::TypeError(
                                format!("Incompatible types ({} and {}) for this operator", a.type_to_string(), b.type_to_string()).to_owned()),
                                span_b))
                        }
                    }
                    _ => Err(Spanned::new(Error::TypeError(
                        format!("Incompatible types ({} and {}) for this operator", a.type_to_string(), b.type_to_string()).to_owned()),
                        span_b))
                }
            }
            _ => Err(Spanned::new(
                    Error::TypeError(format!("Operand A (type {}) does not support this operator", a.type_to_string()).to_owned()),
                    span_a))
        }
    }
}