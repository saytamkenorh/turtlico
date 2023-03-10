use std::{collections::HashMap};

use chumsky::{prelude::Simple};

use crate::{ast::{Expression, Spanned}, error::{Error, RuntimeError}, value::{Value, Library, Callable, LibraryContext}, stdlib};

enum MathOperator {
    Addition,
    Subtraction,
    Multiply,
    Division,
    Comparison
}

pub struct Context<'a> {
    parent: Option<&'a Context<'a>>,
    pub vars: HashMap<String, Value>,
    libctx: HashMap<String, Box<dyn LibraryContext>>
}

impl<'a> Context<'a> {
    pub fn new_parent() -> Self {
        let mut this = Self {
            parent: None,
            vars: HashMap::new(),
            libctx: HashMap::new()
        };
        this.import_library(stdlib::init_library(), false);
        this
    }

    pub fn substitute(&'a self) -> Self {
        Self {
            parent: Some(self),
            vars: HashMap::new(),
            libctx: HashMap::new()
        }
    }

    pub fn eval_root(&mut self, expression: &Spanned<Expression>) -> Result<Value, Spanned<Error>> {
        match self.eval(expression) {
            Ok(Value::EvaluatedReturn(value)) => Ok(*value),
            other => other
        }
    }

    fn eval(&mut self, expression: &Spanned<Expression>) -> Result<Value, Spanned<Error>> {
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
                        match callable {
                            Callable::NativeFunc(func) => {
                                //let func = self.get_var(&name)?;
                                let mut func_args = vec![];
                                for arg in args {
                                    func_args.push(self.eval(&arg)?);
                                }
                                let ctx = self.libctx.get_mut(&func.library).unwrap();
                                let result = (func.func)(ctx, func_args).map_err(
                                    |err| Spanned::new(Error::RuntimeError(err), expression.span.to_owned()));
                                match result {
                                    Ok(Value::EvaluatedReturn(value)) => {
                                        return Ok(*value);
                                    },
                                    other_result => other_result
                                }
                            },
                            Callable::Function => {
                                todo!()
                            }
                        }
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
                                            self.vars.insert(var.to_owned(), Value::Int(i));
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
            // Keywords
            Expression::Assignment { expr, value } => {
                match &expr.item {
                    Expression::Variable(variable) => {
                        let value = self.eval(&value)?;
                        let oldval = self.vars.insert(variable.to_owned(), value);
                        Ok(oldval.unwrap_or(Value::None))
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
            Expression::Comparison(a, b) => {
                self.math_operator(a, b, MathOperator::Comparison)
            },
            // Literals
            Expression::Int(val) => Ok(Value::Int(*val)),
            Expression::Float(val) => Ok(Value::Float(*val)),
            Expression::String(val) => Ok(Value::String(val.to_owned())),
            Expression::Variable(name) => Ok(self.get_var(&name).map_err(|err| Spanned::new(err, expression.span.to_owned()))?.clone()),
            _ => {
                Err(Spanned::new(Error::SyntaxError(Simple::custom(expression.span.clone(), "Interpreter error: unexpected expression")), expression.span.to_owned()))
            }
        }
    }

    fn get_var(&self, name: &str) -> Result<&Value, Error> {
        match self.vars.get(name) {
            Some(value) => Ok(value),
            None => {
                match self.parent {
                    Some(parent) => parent.get_var(name),
                    None => Err(Error::RuntimeError(RuntimeError::InvalidIdentifier(name.to_owned()))),
                }
            }
        }
    }

    pub fn import_library(&mut self, lib: Library, prefix_name: bool) {
        let libname = lib.name;
        self.vars.extend(lib.vars.into_iter().map(|(key, value)| {
            (if prefix_name {libname.to_owned() + "." + &key} else {key}, value)
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
                            MathOperator::Comparison => Ok(Value::Bool(val_a == val_b)),
                        }
                    },
                    Value::Float(val_b) => {
                        match op {
                            MathOperator::Addition => Ok(Value::Float(f64::from(*val_a) + val_b)),
                            MathOperator::Subtraction => Ok(Value::Float(f64::from(*val_a) - val_b)),
                            MathOperator::Multiply => Ok(Value::Float(f64::from(*val_a) * val_b)),
                            MathOperator::Division => Ok(Value::Float(f64::from(*val_a) / val_b)),
                            MathOperator::Comparison => Ok(Value::Bool(f64::from(*val_a) == *val_b)),
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
                            MathOperator::Comparison => Ok(Value::Bool(val_a == val_b)),
                        }
                    },
                    Value::Int(val_b) => {
                        match op {
                            MathOperator::Addition => Ok(Value::Float(val_a + f64::from(*val_b))),
                            MathOperator::Subtraction => Ok(Value::Float(val_a - f64::from(*val_b))),
                            MathOperator::Multiply => Ok(Value::Float(val_a * f64::from(*val_b))),
                            MathOperator::Division => Ok(Value::Float(val_a / f64::from(*val_b))),
                            MathOperator::Comparison => Ok(Value::Bool(*val_a == f64::from(*val_b))),
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
                            MathOperator::Comparison => Ok(Value::Bool(val_a == val_b)),
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